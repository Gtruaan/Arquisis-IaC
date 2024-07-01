# IaC E3 Arquitectura de Sistemas de Software

A continuación, se documenta el proceso para levantar toda la infraestructura necesaria para correr la aplicación de Ark Airlines mediante IaC.

## Estructura

Este repositorio contiene toda la infraestructura como código (IaC) necesaria para desplegar los componentes tanto del backend como del frontend para la aplicación.

## Despliegue del backend

Para desplegar el backend de la aplicación, primero se debe tener instalado Terraform, y se debe haber realizado la configuración de las credenciales de AWS en AWS CLI.

Es necesario contar con la llave `base-key.pem` para acceder a la instancia EC2 creada. Esta es la llave manejada por el equipo y no se encuentra en el repositorio.

Link relevante: https://developer.hashicorp.com/terraform/tutorials/aws-get-started

### Pasos a seguir

1. Ingresar a la carpeta `backend`
```bash
cd backend
```

2. En el script `configure-ec2.sh` de la carpeta scripts, se deben modificar las siguientes líneas con los valores correspondientes:
    * línea 145: `personal_access_token` con el personal access token de una cuenta de GitHub con acceso al repositorio del backend.
    * línea 165: `AUTH0_DOMAIN` con el dominio de Auth0.
    * línea 166: `AUTH0_AUDIENCE` con el audience de Auth0.
    * línea 167: `LAMBDA_API_URL` con la URL de la API de una lambda creada para comunicarse con un bucket S3.

3. Inicializar Terraform
```bash
terraform init
```

4. Crear un plan de ejecución
```bash
terraform plan -out deployment.tfplan
```

5. Aplicar el plan de ejecución
```bash
terraform apply deployment.tfplan
```

6. Una vez finalizado el despliegue, se mostrarán las direcciones IP públicas de la instancia EC2 creada, junto con un comando para entrar con SSH para la key `base-key.pem` que utiliza el equipo.

7. Se debe ingresar a la instancia EC2 y realizar lo siguiente:
    * Modificar `LAMBDA_API_URL` en el archivo `Arquisis-Back/api/.env` de root si es pertinente.
    * Utilizar `sudo docker compose up` para levantar los contenedores de la aplicación.
    * Iniciar CERTBOT y configurarlo con los dominios de la aplicación.

8. Finalmente, se deben configurar los siguientes componentes manualmente:
    * Generar la Lambda y configurarla con el bucket S3 para almacenar boletas. Crear los roles pertinentes.
    * Configurar el API Gateway con los recursos asociados y la lambda de autenticación Auth0.

El despliegue de infraestructura genera las siguientes instancias:
* Una instancia EC2 t2.micro con Ubuntu 22.04 y Nginx, de nombre `e3-iac-ec2`.
* Elastic IP y Security Group para la instancia EC2, de nombres `e3-iac-eip` y `e3-iac-sg` respectivamente.
* Un bucket S3 con los permisos y policies asociados para almacenar boletas, de nombre `e3-iac-s3-receipts`.
* Un API Gateway de nombre `e3-iac-api`.

### Outputs

* `elastic_ip`: Dirección IP pública de la instancia EC2.
* `ssh_command`: Comando para acceder a la instancia EC2 con SSH.
* `api_id`: ID del API Gateway creado.
* `s3_bucket`: Nombre del bucket S3 creado para las boletas.


## Despliegue del frontend

Para desplegar el frontend de la aplicación, nuevamente se debe tener instalado Terraform, y se debe haber realizado la configuración de las credenciales de AWS en AWS CLI.

A continuación, se deben seguir los siguientes pasos:

1. Ingresar a la carpeta `frontend`
```bash
cd frontend
```

2. Inicializar Terraform
```bash
terraform init
```

3. Crear un plan de ejecución
```bash
terraform plan -out deployment.tfplan
```

4. Aplicar el plan de ejecución
```bash
terraform apply deployment.tfplan
```

5. Una vez finalizado el despliegue, se mostrará la dirección de la distribución de CloudFront creada. Se deben cargar los archivos de una build del frontend en el bucket S3 creado.

6. Para finalizar, se debe generar un behavior en la distribución de CloudFront para redirigir HTTP a HTTPS, en caso de continuar con certificado SSL.

El despliegue de infraestructura genera las siguientes instancias:
* Un bucket S3 con los permisos y policies asociados para almacenar el frontend, de nombre `e3-iac-s3-frontend`.
* Una distribución de CloudFront con el bucket S3 como origen, de nombre `e3-iac-cloudfront`.

### Outputs

* `s3_bucket`: Nombre del bucket S3 creado para el frontend.
* `cloudfront_domain_name`: Dominio de la distribución de CloudFront.

