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
