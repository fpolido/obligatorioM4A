# Obligatorio M4A

Este repositorio contiene dos scripts principales:
- Script Bash `Bash/ej1_crea_usuarios.sh` para crear usuarios en el sistema.
- Script Python `Python/crear_infra.py` para crear infraestructura en AWS y pone en marcha la app.

# 1. Script Bash – Creación de Usuarios

## Descripción
El script permite crear usuarios basándose en la información contenida en un archivo externo.  
Incluye:
- Opción `-i` para mostrar información detallada.
- Opción `-c` para asignar una contraseña a todos los usuarios.
- Validaciones, manejo de errores y códigos de salida diferenciados.
- Resumen final de cuántos usuarios fueron creados correctamente.

## Requisitos
- Sistema Linux con intérprete **bash**.
- Permisos de administrador (sudo).
- Archivo de entrada con formato: usuario:comentario:home:SI/NO:shell

## Modo de uso
Ejecutar:
```bash
./ej1_crea_usuarios.sh [-i] [-c contraseña] Usuarios.txt
```

Este comando:
- Crea cada usuario listado en el archivo.
- Asigna la contraseña (contraseña) a todos (-c).
- Muestra información detallada (-i).
- Informa errores si existen líneas mal formadas o si un usuario no se puede crear.

## Verificación de resultados
Ejecutar:
```bash
cat /etc/passwd
```
Deberían aparecer los usuarios creados

# 2. Script Python – Automatización de Infraestructura AWS

## Descripción
Este script automatiza la creación de infraestructura necesaria para ejecutar una aplicación web de recursos humanos. Se utiliza `boto3` y un archivo `.env` para cargar credenciales y parámetros.  
El script crea:

- Un par de claves (.pem)
- Security Groups
- Reglas de SSH y HTTP
- RDS (MySQL/MariaDB)  
- EC2 con Apache + PHP
- Archivo `.env` interno con los valores de conexión
- Descarga de la app desde este repositorio

El despliegue es completamente automático y la EC2 queda con la app funcionando.

## Requisitos
- Archivo `.env` en la carpeta del script Python con el formato de env.example:

### Requisitos técnicos:
- Python 3.8 o superior.
- Crear entorno virtual:
```bash
python3 -m venv venv
source venv/bin/activate
```
- Instalar dependencias:
```bash
pip install boto3 python-dotenv
```

### Requisitos de AWS:
- Credenciales con permisos suficientes en:
  - Archivo `.env` en la carpeta `Python/`
  - Archivo local `~/.aws/credentials`. Esto es necesario porque boto3 también consulta estas credenciales:
```bash
mkdir -p ~/.aws
vim ~/.aws/credentials
```
Contenido:
```bash
[default]
aws_access_key_id=xxxxx
aws_secret_access_key=yyyyy
aws_session_token=zzzzz
```

## Modo de uso
Para ejecutar el script:
```bash
python3 crear_infra.py
```
Este comando:
- Genera toda la infraestructura AWS automáticamente.
- Crea una EC2 con Apache y PHP.
- Construye el archivo `.env` dentro del servidor.
- Conecta la aplicación con la base de datos RDS.
- Muestra la IP pública de la instancia para ingresar a la web.

## Verificación de resultados
Abrir un navegador web y entrar a:
```bash
http://IP_PUBLICA/login.php
```
Debería mostrarse la pantalla de login de la aplicación donde poner las siguientes credenciales
- Usuario `admin`
- Contraseña: `admin123`
