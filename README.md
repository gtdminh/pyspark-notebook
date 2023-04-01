Cloned from https://github.com/jupyter/docker-stacks/tree/main/pyspark-notebook

* Added postgres jdbc jar
* Added mysql jar
* Added snowflake jar

Run: 
* docker pull gtdminh/pyspark-notebook
* docker run --name pyspark -p 8888:8888 -p 4040:4040 -d gtdminh/pyspark-notebook