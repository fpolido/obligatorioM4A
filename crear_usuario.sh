#!/bin/bash

# =================================================================
# ej1_crea_usuarios.sh
# Script para crear usuarios a partir de un archivo de configuración.
# =================================================================

# --- Variables Globales ---
INFO_FLAG=0
PASSWORD=""
USERS_FILE=""
CREATED_COUNT=0
TOTAL_COUNT=0

# --- Funciones de Error ---

# Función para imprimir errores y salir con código distinto de 0
# $1: Mensaje de error a desplegar
# $2: Código de retorno (diferente para cada error)
error_exit() {
    echo "ERROR: $1" >&2
    exit "$2"
}

# --- Procesamiento de Argumentos ---

# Códigos de error:
# 1: Cantidad incorrecta de parámetros
# 2: Modificador inválido
# 3: No se recibió contraseña con -c
# 4: Archivo de usuarios no existe
# 5: Archivo de usuarios no es regular
# 6: Archivo de usuarios sin permisos de lectura

# Controlar la cantidad mínima de argumentos
if [ $# -lt 1 ]; then
    error_exit "Cantidad de parámetros incorrecta. Uso: $0 [-i] [-c contraseña] Archivo_con_los_usuarios_a_crear" 1
fi

# Parsing de opciones y argumentos
while [ "$#" -gt 0 ]; do
    case "$1" in
        -i)
            INFO_FLAG=1
            shift
            ;;
        -c)
            shift
            if [ -z "$1" ]; then
                error_exit "Se usó el modificador -c, pero no se proporcionó una contraseña." 3
            fi
            PASSWORD="$1"
            shift
            ;;
        -*)
            error_exit "Modificador inválido: $1" 2
            ;;
        *)
            # El último argumento sin modificador debe ser el archivo de usuarios
            USERS_FILE="$1"
            shift
            ;;
    esac
done

# Validar que el archivo de usuarios fue especificado
if [ -z "$USERS_FILE" ]; then
    error_exit "Cantidad de parámetros incorrecta o archivo de usuarios no especificado. Uso: $0 [-i] [-c contraseña] Archivo_con_los_usuarios_a_crear" 1
fi

# Validar el archivo de usuarios
if [ ! -f "$USERS_FILE" ]; then
    error_exit "El archivo de usuarios '$USERS_FILE' no existe." 4
elif [ ! -r "$USERS_FILE" ]; then
    error_exit "No se tienen permisos de lectura sobre el archivo de usuarios '$USERS_FILE'." 6
elif [ ! -s "$USERS_FILE" ]; then
    # Opcional: advertir si está vacío, pero se puede procesar
    if [ "$INFO_FLAG" -eq 1 ]; then
        echo "Advertencia: El archivo de usuarios está vacío."
    fi
fi

# --- Lógica Principal de Creación de Usuarios ---

# Código de error 7: Error de sintaxis en el archivo de usuarios
# Código de error 8: Error en la creación del usuario (useradd)
# Código de error 9: Error en la asignación de contraseña (chpasswd)

IFS=$'\n' # Asegurar que 'for' itere por líneas completas
for LINE in $(cat "$USERS_FILE" 2>/dev/null); do
    # Omitir líneas vacías
    if [ -z "$LINE" ]; then
        continue
    fi

    TOTAL_COUNT=$((TOTAL_COUNT + 1))

    # Sintaxis: Nombre:Comentario:Dir home:crear dir home (SI/NO):Shell
    # user_array[0]=Nombre
    # user_array[1]=Comentario
    # user_array[2]=Directorio home
    # user_array[3]=Crear dir home
    # user_array[4]=Shell

    # Contar campos separados por ':'
    FIELD_COUNT=$(echo "$LINE" | grep -o ':' | wc -l)

    # Se esperan 4 separadores, lo que significa 5 campos
    if [ "$FIELD_COUNT" -ne 4 ]; then
        if [ "$INFO_FLAG" -eq 1 ]; then
            echo "ATENCION: La línea tiene sintaxis incorrecta (no contiene exactamente 5 campos separados por ':'). Línea omitida:"
            echo "$LINE"
            echo ""
        fi
        continue
    fi

    # Separar la línea en campos (usando IFS=':')
    IFS=':' read -r USERNAME COMMENT HOME_DIR CREATE_HOME SHELL_BIN <<< "$LINE"

    # Limpiar espacios en blanco innecesarios
    USERNAME=$(echo "$USERNAME" | tr -d '[:space:]')
    COMMENT=$(echo "$COMMENT" | sed 's/^[ \t]*//;s/[ \t]*$//')
    HOME_DIR=$(echo "$HOME_DIR" | tr -d '[:space:]')
    CREATE_HOME=$(echo "$CREATE_HOME" | tr '[:lower:]' '[:upper:]' | tr -d '[:space:]')
    SHELL_BIN=$(echo "$SHELL_BIN" | tr -d '[:space:]')

    # ----------------------------------------
    # Construcción del comando useradd
    # ----------------------------------------

    # Comando base
    USERADD_CMD="useradd"

    # Parámetros para useradd
    PARAMS=""

    # 1. Comentario (-c)
    if [ -n "$COMMENT" ]; then
        PARAMS+="-c \"$COMMENT\" "
        DISPLAY_COMMENT="$COMMENT"
    else
        DISPLAY_COMMENT="< valor por defecto >"
    fi

    # 2. Directorio Home (-d) y Crear Home (-m/-N)
    CREATE_FLAG=""
    if [ "$CREATE_HOME" == "SI" ]; then
        CREATE_FLAG="-m"
        DISPLAY_CREATE_HOME="SI"
    elif [ "$CREATE_HOME" == "NO" ]; then
        # useradd por defecto no crea el directorio si no existe y no se especifica -m
        # Si se especifica -d, useradd asume que existe.
        CREATE_FLAG=""
        DISPLAY_CREATE_HOME="NO (Dir. Home no asegurado)"
    else
        # Si el campo está vacío, useradd usa sus valores por defecto (ej. no crea, /home/user)
        # Aquí permitimos que use el valor por defecto de useradd
        CREATE_FLAG=""
        DISPLAY_CREATE_HOME="< valor por defecto >"
    fi

    # Si se especificó un directorio home, lo incluimos
    if [ -n "$HOME_DIR" ]; then
        PARAMS+="-d \"$HOME_DIR\" "
        DISPLAY_HOME_DIR="$HOME_DIR"
    else
        # Si HOME_DIR no se especifica, useradd usará el valor por defecto
        DISPLAY_HOME_DIR="< valor por defecto >"
        # Si se especificó SI en 'crear dir home' pero no hay path, no se incluye -d.
    fi

    # Agregar la bandera de creación/no-creación de home (si aplica)
    if [ -n "$CREATE_FLAG" ]; then
         PARAMS+="$CREATE_FLAG "
    fi

    # 3. Shell por defecto (-s)
    if [ -n "$SHELL_BIN" ]; then
        # useradd requiere que el shell exista en /etc/shells, pero lo intentamos de todas formas
        PARAMS+="-s \"$SHELL_BIN\" "
        DISPLAY_SHELL="$SHELL_BIN"
    else
        DISPLAY_SHELL="< valor por defecto >"
    fi

    # ----------------------------------------
    # Ejecutar useradd y manejar resultado
    # ----------------------------------------

    # Comando final
    FULL_CMD="$USERADD_CMD $PARAMS \"$USERNAME\""

    # Solo ejecutar si no está en modo simulación (para sistemas reales se requiere 'sudo')
    # Se asume que el script se ejecuta con los permisos necesarios (ej. root/sudo)
    eval "$FULL_CMD" 2>/dev/null
    USERADD_EXIT_CODE=$?

    # Asignación de contraseña
    PASSWD_EXIT_CODE=0
    if [ "$USERADD_EXIT_CODE" -eq 0 ] && [ -n "$PASSWORD" ]; then
        # Asignar contraseña usando chpasswd (más seguro para scripts)
        echo "$USERNAME:$PASSWORD" | chpasswd
        PASSWD_EXIT_CODE=$?
    fi

    # ----------------------------------------
    # Desplegar información (-i)
    # ----------------------------------------
    if [ "$INFO_FLAG" -eq 1 ]; then
        if [ "$USERADD_EXIT_CODE" -eq 0 ]; then
            if [ "$PASSWD_EXIT_CODE" -eq 0 ]; then
                echo "Usuario $USERNAME creado con éxito con datos indicados:"
                CREATED_COUNT=$((CREATED_COUNT + 1))
            else
                echo "ATENCION: El usuario $USERNAME fue creado, pero la contraseña no pudo ser asignada (código $PASSWD_EXIT_CODE)."
                CREATED_COUNT=$((CREATED_COUNT + 1)) # Se cuenta como creado si el usuario existe
            fi

            echo "Comentario: $DISPLAY_COMMENT"
            echo "Dir home: $DISPLAY_HOME_DIR"
            echo "Asegurado existencia de directorio home: $DISPLAY_CREATE_HOME"
            echo "Shell por defecto: $DISPLAY_SHELL"
        else
            # 9 indica que el usuario ya existe, 12 que el home dir no se puede crear/existe, 3 un nombre inválido, etc.
            echo "ATENCION: El usuario $USERNAME no pudo ser creado (código de error $USERADD_EXIT_CODE)."
        fi
        echo "" # Línea vacía de separación entre usuarios
    elif [ "$USERADD_EXIT_CODE" -eq 0 ]; then
        CREATED_COUNT=$((CREATED_COUNT + 1))
    fi

done
IFS=$' \t\n' # Restaurar IFS por defecto

# --- Resumen Final ---
if [ "$INFO_FLAG" -eq 1 ]; then
    echo "Se han creado $CREATED_COUNT usuarios con éxito."
fi

# El script termina con éxito si llega hasta aquí
exit 0

