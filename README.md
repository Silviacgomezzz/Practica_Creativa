# Instrucciones de despliegue

 A continuación se detallan los pasos para desplegar el entorno completo y las comprobaciones necesarias.

## 1. Despliegue de la arquitectura con Docker

El primer objetivo de esta práctica consiste en dockerizar todos los servicios y levantar el entorno completo con Docker Compose.

---

### Servicios dockerizados

- **MongoDB**: Base de datos para guardar resultados de predicciones.
- **Apache Kafka**: Sistema de mensajería para enviar/recibir predicciones.
- **Flask App**: Aplicación web para introducir predicciones.
- **Apache Spark**: Motor de procesamiento para hacer predicciones (master, workers, submit).
- **Apache NiFi**: Herramienta para leer datos de Kafka y procesarlos.
- **Hadoop HDFS**: Almacenamiento distribuido donde se escriben los resultados en formato `.parquet`.

### Pasos para desplegar

1. **Clonar  repositorio**  
   git clone <URL_DEL_REPOSITORIO>

   cd <nombre_del_proyecto>

2. **Lanzar todos los servicios con Docker Compose**

    docker compose up 

    Este comando construye y arranca todos los servicios.

 3. **Verifica que los servicios están funcionando**

    Consulta el estado de los contenedores:

    docker compose ps

4. **Accede a las interfaces web**

   Flask UI: [http://localhost:5001](http://localhost:5001/flights/delays/predict_kafka)

   Spark Master: http://localhost:8086

   NiFi: http://localhost:8080

   HDFS UI: http://localhost:9870


## 2. Escribir las predicciones en Kafka y mostrarlas en la aplicación (manteniendo MongoDB)

En este paso hemos modificado el código de Spark para que las predicciones se escriban en:

- **MongoDB**: se sigue almacenando cada predicción.
- **Kafka**: se envía cada predicción al tópico `flight-delay-ml-response`.
- **Flask App**: recupera los mensajes desde Kafka y los muestra por la interfaz.


### Verificar que se escribió en Kafka

1. **Enviar una predicción desde la app**

    Abre tu navegador en: [http://localhost:5001](http://localhost:5001/flights/delays/predict_kafka)

    Rellena los campos y haz clic en Enviar predicción.

   ![5001](https://github.com/user-attachments/assets/36e73892-527b-4d50-bfe9-ba00190e9636)


3. **Accede al contenedor kafka**

   docker exec -it kafka bash

   Luego ejecuta:
   kafka-console-consumer.sh \
  --bootstrap-server kafka:9092 \
  --topic flight-delay-ml-response \
  --from-beginning
  
    Deberías ver JSONs con las predicciones completas.

4. **Verificar que se guardó en MongoDB**

   Accede al contenedor de Mongo:
   ```bash
   docker exec -it mongo mongosh
   show dbs
   use agile_data_science
   db.flight_delay_ml_response.find().pretty()

  Cada documento debe contener los datos de entrada más la predicción.

## 3. Desplegar NiFi y guardar predicciones en un fichero `.txt` cada 10 segundos

Este paso consiste en usar **Apache NiFi** para:

- Leer mensajes del tópico Kafka `flight-delay-ml-response`.
- Hacerlo **cada 10 segundos**.
- Guardarlos en un archivo `.txt`.

### Despliegue de NiFi
Ya está incluido en `docker-compose.yml`. Puedes acceder a la interfaz desde tu navegador:

 http://localhost:8080

### Flujo en NiFi

Desde la interfaz gráfica, hemos creado el siguiente flujo:

![nifi](https://github.com/user-attachments/assets/414d14be-6bd1-4a79-8ad6-9ceeee2538a9)


#### Configuración de `ConsumeKafka_2_6`

- **Kafka brokers**: `kafka:9092`
- **Topic Name**: `flight-delay-ml-response`
- **Group ID**: `nifi-group`
- **Auto Offset Reset**: `earliest`
En scheduling:
- **Run schedule**: `10 sec`


####  Configuración de `PutFile`

- **Directory**: `/opt/nifi/nifi_out`
- **Conflict Resolution Strategy**: `replace`
- Este directorio está mapeado localmente en `./nifi_out/`.

### Verificación

1. Envía una predicción desde Flask.
2. Espera unos segundos y revisa:

    ls ./nifi_out/

3. Abre los .txt generados:
   
cat <nombre_del_txt>

Deberías ver las predicciones en formato JSON.

## 4. Escribir las predicciones en HDFS en lugar de MongoDB

En este paso hemos modificado el código de Spark para guardar también las predicciones en **HDFS** en formato `.parquet`. Se mantienen los destinos anteriores: MongoDB y Kafka.

El resultado se escribirá en la ruta /user/spark/output en HDFS.

El checkpoint del stream se guarda en /tmp/hdfs_checkpoint

   **Verifica si existen los ficheros .parquet:**
 
    docker exec -it hadoop-datanode bash
    hdfs dfs -ls /user/spark/flight_prediction
    hdfs dfs -cat <nombre_del_parquet>

###  Evidencia visual del guardado en HDFS

A continuación accedemos al explorador web de Hadoop (`http://localhost:9870`). Vamos a la sección de "Utilities" y a "Browse the file system". Ahora entramos en la ruta `/user/spark/flight_prediction`, donde se están guardando correctamente las predicciones en formato `.parquet`.

![hdfs](https://github.com/user-attachments/assets/7a3d7427-ea6e-4f6a-a90b-340ff156859e)


 Esto confirma que el flujo de:
**Kafka ➜ Spark ➜ HDFS**
está funcionando correctamente.

