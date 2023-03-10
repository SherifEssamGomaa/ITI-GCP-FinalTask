# ITI-GCP-FinalTask
## Prerequisites
To be able to run the project make sure you already have the following:
- Terraform installed on your system
- Docker installed on your system
- Google Cloud Platform account linked with Terraform, you can use this [link](https://www.youtube.com/watch?v=LXZC2i8LNxQ) to do so
## Setup
This is the flow you should follow to be able to run the app:
- Download the project as a zip file by clicking on the <> code green button o the uper right corner and choose download zip from the menu
- Extract the project files
- Open a terminal in the project directory
- Run 
``` 
terraform init 
```
- Run
 ``` 
 terraform apply
 ```
- Now, you have the infrastructure ready on your GCP account
- ssh on the created VM instance
- upload the kubernetes files on it
- Connect the instance with the cluster by runnin this command on the instance and replace the YOUR_ZONE and YOUR_PROJECT_ID with your values
``` 
gcloud container clusters get-credentials private-cluster --zone YOUR_ZONE --project YOUR_PROJECT_ID 
```
- Wait for a couple of minutes, I am installing some softwares for you on your machine :smile:
- Run 
```
kubectl apply -f redis-deployment.yaml 
```
- Run 
``` 
kubectl apply -f app-deployment.yaml 
```
- Run 
``` 
kubectl apply -f app-ingress.yaml 
```
- Wait for another couple of minutes till the ingress is ready for you
- Run 
``` 
kubectl get ingress 
```
- Copy the ip and paste it in your web browser address field and hit it
- :tada: :tada: :tada: Enjoy the counter 