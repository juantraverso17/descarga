#!/bin/bash
# Verificar si el script se está ejecutando desde el directorio correcto
if [ "$(basename "$PWD")" != "wso2am" ]; then
    echo "El directorio actual no es wso2am. Terminando la ejecución del script."
    exit 1
fi

# Verificar si el contenedor está en ejecución
CONTAINER_NAME="wso2am"
if docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null; then
    echo "El contenedor $CONTAINER_NAME está en ejecución."
else
    echo "El contenedor $CONTAINER_NAME no está en ejecución. Terminando la ejecución del script..."
    exit 1
fi

# Variables
DOCKER_COMPOSE_YML=./docker-compose.yml
CONTAINER_DEPLOYMENT_TOML=/home/wso2carbon/wso2am-3.2.0/repository/conf/deployment.toml
DEPLOYMENT_TOML="./conf/apim/repository/conf/deployment.toml"
SUPER_ADMIN_USER=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[super_admin\]/{flag=1; next} /\[/{flag=0} flag && /username/{$1=$1; print $2}')
SUPER_ADMIN_PASSWORD=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[super_admin\]/{flag=1; next} /\[/{flag=0} flag && /password/{$1=$1; print $2}')
DATABASE_APIM_DB_USER=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[database.apim_db\]/{flag=1; next} /\[/{flag=0} flag && /username/{$1=$1; print $2}')
DATABASE_APIM_DB_PASSWORD=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[database.apim_db\]/{flag=1; next} /\[/{flag=0} flag && /password/{$1=$1; print $2}')
DATABASE_SHARED_DB_USER=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[database.shared_db\]/{flag=1; next} /\[/{flag=0} flag && /username/{$1=$1; print $2}')
DATABASE_SHARED_DB_PASSWORD=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[database.shared_db\]/{flag=1; next} /\[/{flag=0} flag && /password/{$1=$1; print $2}')

HOST_SUPER_ADMIN_USER=$(cat ${DEPLOYMENT_TOML} | awk -F '"' '/\[super_admin\]/{flag=1; next} /\[/{flag=0} flag && /username/{$1=$1; print $2}')
HOST_SUPER_ADMIN_PASSWORD=$(cat ${DEPLOYMENT_TOML} | awk -F '"' '/\[super_admin\]/{flag=1; next} /\[/{flag=0} flag && /password/{$1=$1; print $2}')
HOST_DATABASE_APIM_DB_USER=$(cat ${DEPLOYMENT_TOML} | awk -F '"' '/\[database.apim_db\]/{flag=1; next} /\[/{flag=0} flag && /username/{$1=$1; print $2}')
HOST_DATABASE_APIM_DB_PASSWORD=$(cat ${DEPLOYMENT_TOML} | awk -F '"' '/\[database.apim_db\]/{flag=1; next} /\[/{flag=0} flag && /password/{$1=$1; print $2}')
HOST_DATABASE_SHARED_DB_USER=$(cat ${DEPLOYMENT_TOML} | awk -F '"' '/\[database.shared_db\]/{flag=1; next} /\[/{flag=0} flag && /username/{$1=$1; print $2}')
HOST_DATABASE_SHARED_DB_PASSWORD=$(cat ${DEPLOYMENT_TOML} | awk -F '"' '/\[database.shared_db\]/{flag=1; next} /\[/{flag=0} flag && /password/{$1=$1; print $2}')

#Funciones

obtener_y_sustituir_valores() {
    echo "[*] Obteniendo valores ofuscados desde el contenedor"
    SUPER_ADMIN_PASSWORD_SECRET=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[secrets\]/{flag=1; next} /\[/{flag=0} flag && /super_admin/{$1=$1; print $2}')
    APIM_DB_PASSWORD_SECRET=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[secrets\]/{flag=1; next} /\[/{flag=0} flag && /apim_db/{$1=$1; print $2}')
    SHARED_DB_PASSWORD_SECRET=$(docker exec -it wso2am cat ${CONTAINER_DEPLOYMENT_TOML} | awk -F '"' '/\[secrets\]/{flag=1; next} /\[/{flag=0} flag && /shared_db/{$1=$1; print $2}')
    echo "SUPER_ADMIN_PASSWORD_SECRET = $SUPER_ADMIN_PASSWORD_SECRET"
    echo "APIM_DB_PASSWORD_SECRET = $APIM_DB_PASSWORD_SECRET"
    echo "SHARED_DB_PASSWORD_SECRET = $SHARED_DB_PASSWORD_SECRET"

    echo "[*] Sustituyendo por valores ofuscados en deployment.toml"
    preguntar_continuar
    # Pregunta antes de realizar cada cambio
    if [ -n "$SUPER_ADMIN_PASSWORD_SECRET" ]; then
        sed -i "s!super_admin = \".*\"!super_admin = \"$SUPER_ADMIN_PASSWORD_SECRET\"!" "$DEPLOYMENT_TOML"
        sed -i '/^\[super_admin\]$/,/^[[]/ s/password = ".*"/password = "$secret{super_admin}"/' "$DEPLOYMENT_TOML"
    fi

    if [ -n "$APIM_DB_PASSWORD_SECRET" ]; then
        sed -i "s!apim_db = \".*\"!apim_db = \"$APIM_DB_PASSWORD_SECRET\"!" "$DEPLOYMENT_TOML"
        sed -i '/^\[database.apim_db\]$/,/^[[]/ s/password = ".*"/password = "$secret{apim_db}"/' "$DEPLOYMENT_TOML"
    fi

    if [ -n "$SHARED_DB_PASSWORD_SECRET" ]; then
        sed -i "s!shared_db = \".*\"!shared_db = \"$SHARED_DB_PASSWORD_SECRET\"!" "$DEPLOYMENT_TOML"
        sed -i '/^\[database.shared_db\]$/,/^[[]/ s/password = ".*"/password = "$secret{shared_db}"/' "$DEPLOYMENT_TOML"
    fi
}

preguntar_continuar() {
    read -p "¿Desea continuar? (Presione Y para sí): " respuesta
    if [ "$respuesta" != "Y" ] && [ "$respuesta" != "y" ]; then
        echo "Operación cancelada."
        exit 1
    fi
}
ejecutar_ciphertool_Dconfigure() {
    echo "[*] Ejecutando ciphertool"
    echo "Ingrese \"wso2carbon\" para continuar"
    docker exec -it wso2am /home/wso2carbon/wso2am-3.2.0/bin/ciphertool.sh -Dconfigure
}

ejecutar_ciphertool_Dchange() {
    echo "[*] Ejecutando ciphertool"
    echo "Ingrese \"wso2carbon\" para continuar"
    docker exec -it wso2am /home/wso2carbon/wso2am-3.2.0/bin/ciphertool.sh -Dchange
}

# Menu
clear
echo "1. Chequeo de estado"
echo "2. Ofuscar credenciales wso2am"
echo "3. cambio de clave wso2am"
read -p "Seleccione una opción: " OPTION
clear

case "$OPTION" in
1)
    clear
    echo "#########################"
    echo "#  DATOS DEL CONTENEDOR #"
    echo "#########################"
    echo "CONTAINER_DEPLOYMENT_TOML = $CONTAINER_DEPLOYMENT_TOML"
    echo "SUPER_ADMIN_USER = $SUPER_ADMIN_USER"
    echo "SUPER_ADMIN_PASSWORD = $SUPER_ADMIN_PASSWORD"
    echo "DATABASE_APIM_DB_USER = $DATABASE_APIM_DB_USER"
    echo "DATABASE_APIM_DB_PASSWORD = $DATABASE_APIM_DB_PASSWORD"
    echo "DATABASE_SHARED_DB_USER = $DATABASE_SHARED_DB_USER"
    echo "DATABASE_SHARED_DB_PASSWORD = $DATABASE_SHARED_DB_PASSWORD"
    echo ""
    echo "#########################"
    echo "#   DATOS DEL VOLUMEN   #"
    echo "#########################"
    echo "DEPLOYMENT_TOML = $DEPLOYMENT_TOML"
    echo "HOST_SUPER_ADMIN_USER = $HOST_SUPER_ADMIN_USER"
    echo "HOST_SUPER_ADMIN_PASSWORD = $HOST_SUPER_ADMIN_PASSWORD"
    echo "HOST_DATABASE_APIM_DB_USER = $HOST_DATABASE_APIM_DB_USER"
    echo "HOST_DATABASE_APIM_DB_PASSWORD = $HOST_DATABASE_APIM_DB_PASSWORD"
    echo "HOST_DATABASE_SHARED_DB_USER = $HOST_DATABASE_SHARED_DB_USER"
    echo "HOST_DATABASE_SHARED_DB_PASSWORD = $HOST_DATABASE_SHARED_DB_PASSWORD"
    ;;
2)
    # Verificar si la sección [secrets] ya existe en el archivo
    preguntar_continuar
    echo "[*] Verificando si existe la seccion [secrets] en deployment.toml"
    if grep -q "\[secrets\]" "$DEPLOYMENT_TOML"; then
        echo "La sección [secrets] ya existe en $DEPLOYMENT_TOML. No se realizarán cambios."
    else

        # Agregar la sección [secrets] al final del archivo
        cat <<EOF >>"$DEPLOYMENT_TOML"

[secrets]
super_admin = "[admin]"
apim_db = "[wso2carbon]"
shared_db = "[wso2carbon]"
EOF
        echo "Sección [secrets] agregada exitosamente a $DEPLOYMENT_TOML."
    fi

    # Ejecutar "docker compose -version"
    echo "[*] Chequeando version de docker compose"
    if docker compose version &>/dev/null; then
        DOCKER_COMPOSE_COMMAND="docker compose"
    else
        DOCKER_COMPOSE_COMMAND="docker-compose"
    fi
    echo "Se está utilizando: $DOCKER_COMPOSE_COMMAND"

    # Recreando contenedor wso2am
    echo "[*] Recreando contenedor de wso2am"
    docker stop wso2am && docker rm -f wso2am && $DOCKER_COMPOSE_COMMAND -f $DOCKER_COMPOSE_YML up -d wso2am

    # Ofuscacion de secretos
    ejecutar_ciphertool_Dconfigure
    obtener_y_sustituir_valores

    echo "[*] Verificacion de existencia de directorios para volumenes"
    directorios=(
        "./data/apim/repository/conf/security"
        "./data/apim/repository/resources/security"
    )
    # Función para verificar y crear directorios
    verificar_y_crear_directorio() {
        local directorio=$1
        # Verifica si el directorio existe
        if [ -d "$directorio" ]; then
            echo "El directorio '$directorio' ya existe."
        else
            # Crea el directorio si no existe
            mkdir -p "$directorio"
            echo "Se ha creado el directorio '$directorio'."
        fi
    }
    # Itera sobre los directorios y llama a la función
    for dir in "${directorios[@]}"; do
        verificar_y_crear_directorio "$dir"
    done

    echo "[*] Copiando archivos del contenedor al volumen"
    docker cp wso2am:/home/wso2carbon/wso2am-3.2.0/repository/conf/security ./data/apim/repository/conf/
    docker cp wso2am:/home/wso2carbon/wso2am-3.2.0/repository/resources/security ./data/apim/repository/resources/

    echo "[*] Aplicar permisos o+rw recursivos si el directorio existe"
    sudo chmod -R o+rw ./data/apim/repository/conf/security
    sudo chmod -R o+rw ./data/apim/repository/resources/security
    ls -ls ./data/apim/repository/conf/security
    ls -ls ./data/apim/repository/resources/security

    echo "[*] Creando password-tmp"
    echo "wso2carbon" >conf/apim/password-tmp
    sleep 1

    echo "[*] OFUSCACION FINALIZADA..."
    sleep 2
    ;;
3)
    echo "cambio de clave."
    preguntar_continuar
    ejecutar_ciphertool_Dchange
    obtener_y_sustituir_valores
    echo "Debe cambiar la contraseña en la interfaz web (/carbon)"
    ;;
*)
    echo "Opción no válida. Seleccione 1 o 2."
    ;;
esac
exit 0