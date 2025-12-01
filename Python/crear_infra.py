import boto3
import os
from dotenv import load_dotenv

load_dotenv()

KEY_NAME = os.getenv('KEY_NAME')
AWS_ACCESS_KEY_ID = os.getenv('AWS_ACCESS_KEY_ID')
AWS_SECRET_ACCESS_KEY = os.getenv('AWS_SECRET_ACCESS_KEY')
AWS_SESSION_TOKEN = os.getenv('AWS_SESSION_TOKEN')
AWS_REGION = os.getenv('AWS_REGION')
AWS_IMAGE_ID = os.getenv('AWS_IMAGE_ID')
AWS_INSTANCE_TYPE = os.getenv('AWS_INSTANCE_TYPE')
AWS_S3_NAME = os.getenv('AWS_S3_NAME')
AWS_EC2_NAME = os.getenv('AWS_EC2_NAME')
SG_EC2_NAME = os.getenv('SG_EC2_NAME')
SG_DB_NAME = os.getenv('SG_DB_NAME')
DB_IDENTIFIER = os.getenv('DB_IDENTIFIER')
DB_INSTANCE_CLASS = os.getenv('DB_INSTANCE_CLASS')
DB_ENGINE = os.getenv('DB_ENGINE')
DB_MASTER_USER_NAME = os.getenv('DB_MASTER_USER_NAME')
DB_MASTER_PASSWORD = os.getenv('DB_MASTER_PASSWORD')
EC2_APP_USER = os.getenv('EC2_APP_USER')
EC2_APP_GROUP = os.getenv('EC2_APP_GROUP')
APP_REPO_URL = os.getenv('APP_REPO_URL')
APP_DIR = os.getenv('APP_DIR')
APP_PORT = os.getenv('APP_PORT')
DB_PORT = os.getenv('DB_PORT')
DB_APP_USER = os.getenv('DB_APP_USER')
DB_APP_PASSWORD = os.getenv('DB_APP_PASSWORD')
DB_NAME = os.getenv('DB_NAME') 
APP_ADMIN_PASSWORD = os.getenv('APP_ADMIN_PASSWORD')
APP_ADMIN_USER = os.getenv('APP_ADMIN_USER')


def crear_par_claves(nombre):
    # Crear cliente EC2
    ec2 = boto3.client('ec2')

    # Crear el par de claves
    key_name = nombre
    try:
        key_pair = ec2.create_key_pair(KeyName=key_name)
        with open(f'{key_name}.pem', 'w') as file:
            file.write(key_pair['KeyMaterial'])
        os.chmod(f'{key_name}.pem', 0o400)
        print(f"Par de claves creado y guardado como {key_name}.pem")
    except ec2.exceptions.ClientError as e:
        if 'InvalidKeyPair.Duplicate' in str(e):
            print(f"La clave {key_name} ya existe")
        else:
            raise


def crear_grupo_seguridad(nombre, desc):
    ec2 = boto3.client('ec2')
    sg_id = None
    try:
        response = ec2.create_security_group(GroupName=nombre, Description=desc)
        sg_id = response['GroupId']
        print(f"Grupo de seguridad creado con el id: {sg_id}")
    except ec2.exceptions.ClientError as e:
        if 'InvalidGroup.Duplicate' in str(e):
            print(f"El grupo de seguridad {nombre} ya existe")
            response = ec2.describe_security_groups(
                      Filters=[
                        {
                          'Name': 'group-name',
                          'Values': [nombre]
                        }
                      ])
            if response['SecurityGroups']:
                for sg in response['SecurityGroups']:
                    sg_id = sg['GroupId']
                    print(f"ID del grupo de seguridad: {sg_id}")
            else:
                print("No se encontraron grupos de seguridad con los filtros especificados.")
        else:
            raise
    return sg_id


def crear_reglas(sg_id, sg_ec2_id, puerto, nombre, instancia):
    ec2 = boto3.client('ec2')

    if instancia == "ec2":
        IpPermissions=[{
                       'IpProtocol': 'tcp',
                       'FromPort': puerto,
                       'ToPort': puerto,
                       'IpRanges': [{'CidrIp': '0.0.0.0/0'}]}]
    else:
        IpPermissions=[{
                       'IpProtocol': 'tcp',
                       'FromPort': puerto,
                       'ToPort': puerto,
                       'UserIdGroupPairs': [{'GroupId': sg_ec2_id}]}]

    try:
        ec2.authorize_security_group_ingress(GroupId=sg_id, IpPermissions=IpPermissions)
        print(f"Regla para {nombre} creada")
    except ec2.exceptions.ClientError as e:
        if "InvalidPermission.Duplicate" in str(e):
            print(f"La regla para {nombre} ya existe.")
        else:
            raise


def crear_rds():
    rds = boto3.client("rds")

    db_identifier = DB_IDENTIFIER
    ENGINE = DB_ENGINE 
    USER_NAME = DB_MASTER_USER_NAME
    DB_PASSWORD = DB_MASTER_PASSWORD
    DB_ENDPOINT = None

    db_existe = False

    try:
        response = rds.describe_db_instances(DBInstanceIdentifier=db_identifier)
        print(f"La instancia de rds ya existe")
        db_existe = True
        db = response["DBInstances"][0]
        DB_ENDPOINT = db["Endpoint"]["Address"]
        print(f"El ENDPOINT de la base de datos es {DB_ENDPOINT}")
    except rds.exceptions.ClientError as e:
        # Si el error es que la instancia no se encuentra, retorna False
        if e.response['Error']['Code'] == 'DBInstanceNotFound':
            db_existe = False
        else:
            # Si es otro error, lo lanzamos
            raise

    if not db_existe:
        response = rds.create_db_instance(
               DBInstanceIdentifier=db_identifier,
               AllocatedStorage=20,
               DBInstanceClass=DB_INSTANCE_CLASS,
               Engine=ENGINE,
               MasterUsername=USER_NAME,
               MasterUserPassword=DB_PASSWORD,
               VpcSecurityGroupIds=[sg_db_id]
        )

        print("Instancia rds creada")
        print("Esperando que quede disponible ...")
        waiter = rds.get_waiter('db_instance_available')
        waiter.wait(DBInstanceIdentifier=db_identifier)
        # En este punto la RDS esta lista y pronta para usarse
        # Obtenemos su ENDPOINT
        response = rds.describe_db_instances(DBInstanceIdentifier=db_identifier)
        db = response["DBInstances"][0]
        DB_ENDPOINT = db["Endpoint"]["Address"]
        print(f"El ENDPOINT de la base de datos es {DB_ENDPOINT}")

    return DB_ENDPOINT


def crear_ec2(DB_ENDPOINT):
    ec2_resource = boto3.resource('ec2')

    EC2_INSTANCE_ID = None
    EC2_INSTANCE = None
    DB_HOST = DB_ENDPOINT

    # busco por nombre si ya existe la ec2
    instances = ec2_resource.instances.filter(
        Filters=[
            {"Name": "tag:Name", "Values": [AWS_EC2_NAME]},
            {"Name": "instance-state-name", 
             "Values": ["pending", "running", "stopping", "stopped"]}
        ]
    )
    for instance in instances:
        EC2_INSTANCE = instance
        EC2_INSTANCE_ID = EC2_INSTANCE.instance_id
        break

    ruta_user_data = os.path.join(os.path.dirname(__file__), "user_data.sh")

    with open(ruta_user_data, "r") as f:
        user_data_template = f.read()

    user_data = (
        user_data_template
            .replace("__APP_REPO_URL__", APP_REPO_URL)
            .replace("__DB_HOST__", DB_ENDPOINT)
            .replace("__DB_NAME__", DB_NAME)
            .replace("__DB_APP_USER__", DB_APP_USER)
            .replace("__DB_APP_PASSWORD__", DB_APP_PASSWORD)
            .replace("__DB_MASTER_USER__", DB_MASTER_USER_NAME)
            .replace("__DB_MASTER_PASSWORD__", DB_MASTER_PASSWORD)
            .replace("__APP_ADMIN_USER__", APP_ADMIN_USER)
            .replace("__APP_ADMIN_PASSWORD__", APP_ADMIN_PASSWORD)
    )

    #print(user_data)

    if not EC2_INSTANCE_ID:
        # Crea la instancia
        instances = ec2_resource.create_instances(
            ImageId=AWS_IMAGE_ID,
            MinCount=1,
            MaxCount=1,
            InstanceType=AWS_INSTANCE_TYPE, 
            KeyName=KEY_NAME,
            SecurityGroupIds=[sg_ec2_id],
            UserData=user_data,
            TagSpecifications=[
                {
                    'ResourceType': 'instance',
                    'Tags': [{'Key': 'Name', 'Value': AWS_EC2_NAME}]
                }
            ]
        )
        EC2_INSTANCE = instances[0]
        EC2_INSTANCE_ID = EC2_INSTANCE.id

        print(f"Instancia creada con ID: {EC2_INSTANCE_ID}")
        print(f"Esperando a que la instancia quede en estado running")
        EC2_INSTANCE.wait_until_running()
        EC2_INSTANCE.reload()
    else:
        print(f"La EC2 con el nombre {AWS_EC2_NAME} ya existe y tiene el id: {EC2_INSTANCE_ID}")
        EC2_INSTANCE.reload()

    public_ip = EC2_INSTANCE.public_ip_address
    print(f"La IP publica de la instancia es: {public_ip}")


if __name__ == "__main__":
    crear_par_claves(KEY_NAME)
    sg_ec2_id = crear_grupo_seguridad(SG_EC2_NAME, "SG de la ec2")
    sg_db_id = crear_grupo_seguridad(SG_DB_NAME, "SG de la rds")
    crear_reglas(sg_ec2_id, sg_ec2_id, 22, "SSH", "ec2")
    crear_reglas(sg_ec2_id, sg_ec2_id, 80, "HTTP", "ec2")
    crear_reglas(sg_db_id, sg_ec2_id, 3306, "DB", "rds")
    db_endpoint = crear_rds()
    crear_ec2(db_endpoint)
