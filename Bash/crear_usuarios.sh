#!/bin/bash

mostrar_info=false
password=""
archivo=""

if [ $# -lt 1 ]; then
    echo "Cantidad de parámetros incorrecta. Uso: $0 [-i] [-c contraseña] Archivo_con_los_usuarios_a_crear"
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i)
            mostrar_info=true
            shift
            ;;
        -c)
            if [[ -z "$2" ]]; then
                echo "ERROR: Falta la contraseña después de -c"
                exit 2
            fi
            password="$2"
            shift 2
            ;;
        -*)
            echo "ERROR: Opción inválida: $1"
            exit 3
            ;;
        *)
            if [[ -z "$archivo" ]]; then
                archivo="$1"
            else
                echo "ERROR: Se recibió más de un archivo o parámetro extra"
                exit 4
            fi
            shift
            ;;
    esac
done

if [[ -z "$archivo" ]]; then
    echo "ERROR: No se indicó archivo de usuarios"
    exit 5
fi

if [[ ! -r "$archivo" || ! -f "$archivo" ]]; then
    echo "ERROR: El archivo no es regular o no tiene permisos de lectura"
    exit 6
fi

usuarios_creados=0

while IFS=':' read -r nombre comentario home crear_home shell; do

    # Saltar líneas vacías
    [[ -z "$nombre" ]] && continue

    # Validar cantidad de campos
    campos=$(echo "$nombre:$comentario:$home:$crear_home:$shell" | awk -F':' '{print NF}')
    if [[ $campos -ne 5 ]]; then
        echo "ERROR: Formato incorrecto en el archivo para usuario '$nombre'" >&2
        exit 7
    fi

    # Aplicar valores por defecto si falta alguno
    [[ -z "$comentario" ]] && comentario=""
    [[ -z "$home" ]] && home="/home/$nombre"
    [[ -z "$crear_home" ]] && crear_home="SI"
    [[ -z "$shell" ]] && shell="/bin/bash"

    # Crear el usuario según si hay que asegurar home
    if [[ "$crear_home" == "NO" ]]; then
        if [[ ! -d "$home" ]]; then
            if [[ "$mostrar_info" == true ]]; then
                echo "ATENCION: el usuario $nombre no pudo ser creado"
            fi
            continue
        else
            useradd -M -d "$home" -s "$shell" -c "$comentario" "$nombre" 2>/dev/null
        fi
    else
        useradd -m -d "$home" -s "$shell" -c "$comentario" "$nombre" 2>/dev/null
    fi	
	

    if [[ $? -eq 0 ]]; then
        usuarios_creados=$((usuarios_creados + 1))

        # Asignar contraseña si fue indicada
        if [[ -n "$password" ]]; then
            echo "$nombre:$password" | chpasswd
        fi

        # Mostrar info si corresponde
        if $mostrar_info ; then
            echo "Usuario $nombre creado con éxito con datos indicados:"
            [[ -n "$comentario" ]] && echo -e "\tComentario: $comentario" || echo -e "\tComentario: "
            echo -e "\tDir home: $home"
            echo -e "\tAsegurado existencia directorio home: $crear_home"
            echo -e "\tShell por defecto: $shell"
        fi
    else
        if $mostrar_info ; then
            echo "ATENCIÓN: El usuario $nombre no pudo ser creado"
            echo
        fi
    fi
done < "$archivo"

if $mostrar_info ; then
    echo "Se han creado $usuarios_creados usuarios con éxito."
fi

exit 0
