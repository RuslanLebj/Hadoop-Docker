# Переменные
# Путь в HDFS для загрузки и скачивания файлов
HDFS_PATH=/user/root/input
# Локальная директория, из которой будут загружаться файлы в HDFS
LOCAL_INPUT_DIR=./input
# Локальная директория, в которую будут скачиваться файлы из HDFS
LOCAL_OUTPUT_DIR=./output
# Имя файла для загрузки/скачивания
FILE_NAME=file.txt
# Имя контейнера с namenode (служба HDFS)
HDFS_CONTAINER=namenode
# Путь к исходному коду Java
SRC_DIR=./src
# Имя JAR-файла для запуска
JAR_NAME=WordCount-1.0-SNAPSHOT.jar

# Цели для управления Docker-контейнерами
up:	# Запускает все сервисы, указанные в docker-compose.yaml, в фоновом режиме
	docker-compose up -d

down: # Останавливает и удаляет все контейнеры, а также связанные сети
	docker-compose down

restart: # Перезапускает все контейнеры (остановка и новый запуск)
	docker-compose down && docker-compose up -d

# Заголовок для целей, которые не связаны с файлами
.PHONY: upload download check build run-wordcount clean

# Загрузка файла в HDFS
upload:
	@echo "Uploading $(LOCAL_INPUT_DIR)/$(FILE_NAME) to HDFS ($(HDFS_PATH))..."
	@docker exec -it $(HDFS_CONTAINER) hdfs dfs -mkdir -p $(HDFS_PATH)
	@docker exec -it $(HDFS_CONTAINER) hdfs dfs -put -f $(LOCAL_INPUT_DIR)/$(FILE_NAME) $(HDFS_PATH)
	@echo "File uploaded successfully to HDFS!"

# Проверка содержимого HDFS
check:
	@echo "Checking files in HDFS ($(HDFS_PATH))..."
	@docker exec -it $(HDFS_CONTAINER) hdfs dfs -ls $(HDFS_PATH)

# Скачивание файла из HDFS
download:
	@echo "Downloading output from HDFS to $(LOCAL_OUTPUT_DIR)..."
	@mkdir -p $(LOCAL_OUTPUT_DIR)
	@docker exec -it $(HDFS_CONTAINER) hdfs dfs -get /user/root/output/part-r-00000 /tmp/output.txt
	@docker cp $(HDFS_CONTAINER):/tmp/output.txt $(LOCAL_OUTPUT_DIR)/output.txt
	@docker exec -it $(HDFS_CONTAINER) rm /tmp/output.txt
	@echo "Output downloaded successfully to $(LOCAL_OUTPUT_DIR)/output.txt!"

# Собрать приложение
build:
	@echo "Building Java project in $(SRC_DIR)..."
	@docker run --rm -v $(PWD):/project maven:3.8.5-openjdk-8 sh -c "cd /project && mvn clean package"
	@echo "Build completed! JAR file saved to $(SRC_DIR)/target/$(JAR_NAME)."

# Запустить приложение
run:
	@echo "Running WordCount job on HDFS data..."
	@docker exec -it $(HDFS_CONTAINER) hdfs dfs -rm -r -skipTrash /user/root/output || true
	@docker exec -it $(HDFS_CONTAINER) hadoop jar /src/target/$(JAR_NAME) $(HDFS_PATH) /user/root/output
	@echo "Job completed! Check the output directory in HDFS: /user/root/output"
