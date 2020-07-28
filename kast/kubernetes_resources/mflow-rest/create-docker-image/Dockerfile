FROM python:3.6.8

ENV LIBS=requirements.txt
ENV RESOURCES=resources/

WORKDIR /home
COPY ${LIBS} /home/
COPY ${RESOURCES} /home/


RUN pip install --upgrade pip 
RUN pip install -r ${LIBS} 

EXPOSE 6060

CMD  ["./mlflow_api", "-h", "0.0.0.0", "-p", "6060", "-m", "./KMeans"]
