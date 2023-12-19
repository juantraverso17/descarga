#!/bin/bash

# Variables de conexión a la base de datos
HOST="manager-mysql"
USER="admin"
PASSWORD="admin"
DATABASE="uw2"

clear

echo "1. Desbloquear todos los usuarios"
echo "2. Consultar por un usuario específico"
read -p "Seleccione una opción (1 o 2): " OPTION
clear

case "$OPTION" in
    1)
        # Variables
        read -p "Antigüedad de días que desea consultar: " INTERVAL
        clear

        # Consulta SQL para obtener usuarios
        SQL_QUERY="SELECT last_session, user_name, disabled, disable_reason FROM abstract_user WHERE last_session < CURRENT_TIMESTAMP - INTERVAL ${INTERVAL} DAY ORDER BY user_name;"

        echo "Se mostrarán los usuarios que no han iniciado sesión en un intervalo mayor a ${INTERVAL} días"

        # Ejecutar la consulta utilizando el comando mysql
        docker exec -i manager-mysql mysql -u"$USER" -p"$PASSWORD" -h"$HOST" "$DATABASE" -e "$SQL_QUERY"

        # Pregunta para desbloquear usuarios
        read -p "¿Desea desbloquear todos los usuarios listados? (y/n): " ANSWER

        if [ "$ANSWER" == "y" ]; then
            # Consulta SQL para desbloquear usuarios
            SQL_UNLOCK="UPDATE abstract_user SET last_session = CURRENT_TIMESTAMP, disabled = 0, disable_reason = NULL WHERE last_session < CURRENT_TIMESTAMP - INTERVAL ${INTERVAL} DAY;"
            
            # Ejecutar la consulta de desbloqueo utilizando el comando mysql
            docker exec -i manager-mysql mysql -u"$USER" -p"$PASSWORD" -h"$HOST" "$DATABASE" -e "$SQL_UNLOCK"
            echo "Usuarios desbloqueados exitosamente."
        else
            echo "No se realizaron cambios en los usuarios."
        fi
        ;;
    2)
        while true; do
            # Consultar un usuario específico
            read -p "Ingrese el nombre de usuario a consultar: " USERNAME
            SQL_SPECIFIC_USER="SELECT last_session, user_name, disabled, disable_reason FROM abstract_user WHERE user_name = '$USERNAME';"
            
            # Ejecutar la consulta utilizando el comando mysql
            docker exec -i manager-mysql mysql -u"$USER" -p"$PASSWORD" -h"$HOST" "$DATABASE" -e "$SQL_SPECIFIC_USER"
            
            # Pregunta para desbloquear usuario
            read -p "¿Desea desbloquear el usuario? (y/n): " ANSWER2
            if [ "$ANSWER2" == "y" ]; then
                # Consulta SQL para desbloquear usuario específico
                SQL_UNLOCK_SPECIFIC="UPDATE abstract_user SET last_session = CURRENT_TIMESTAMP, disabled = 0, disable_reason = NULL WHERE user_name = '$USERNAME';"
                
                # Ejecutar la consulta de desbloqueo utilizando el comando mysql
                docker exec -i manager-mysql mysql -u"$USER" -p"$PASSWORD" -h"$HOST" "$DATABASE" -e "$SQL_UNLOCK_SPECIFIC"
                echo "Usuario desbloqueado exitosamente."
            else
                echo "No se realizaron cambios en el usuario."
            fi
            
            # Pregunta para consultar otro usuario
            read -p "¿Desea consultar otro usuario? (y/n): " CONTINUE
            if [ "$CONTINUE" != "y" ]; then
                break
            fi
        done
        ;;
    *)
        echo "Opción no válida. Seleccione 1 o 2."
        ;;
esac