# Wagtail Deployment On Cloud Run  
In this project we will create a simple wagtail application and deploy it on cloud run using cloud build.  
Overview: 

    1. We will create (or/and configure) project and region to use.   
    2. We will enable API's required (refer to table in Resources) for deployment.   
    3. We will create an sql instance, database and user.  
    4. We will create secrets using secret manager.
    5. We will configure iam binidings.  
    6. We will use cloud build to run redis and deploy django app to cloud run.

Clone this repository and change working directory to this repo.  
## Prerequisite  
1. Access to GCP account with permissions to create a project with billing and to enable API's.  
2. CloudSDK set up on local machine or use cloud shell.  
3. Create a new project or use existing one. Configure shell to use this project.  

## Resources

| Resources                   	| Resource Name 	| Details 	|
|-----------------------------	|---------	|---------	|
| SQL Instance                	| SQL_INSTANCE_NAME=myinstance        	| SQL instance and single database will be used by wagtail website <br> Intialize SQL_INSTANCE_ID variable with unique sql intance name with in project        	|   	|
| Google Container Image 	| IMAGE_NAME=my-app        	| Assign Image name with tag like myimage:v1 or only name like myimage to be built and pushed to repository         	|
| Cloud Run Service                  	| SERVICE_NAME=my-app     | Assign a name to service        	|
| Cloud Build                 	|         	|         	|
| Cloud Build Service Account   | CLOUDBUILD=${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com        	| This account is automaticaly created while enabling cloud build api(see API's table) <br> default service account is PROJECT_NUMBER@cloudbuild.gserviceaccount.com      	|
| Cloud Run Service Account     | CLOUDRUN=${PROJECT_NUMBER}-compute@developer.gserviceaccount.com        	  | Cloud Run uses compute engine service account by default <br> default service account is PROJECT_NUMBER-compute@developer.gserviceaccount.com         	|
| Secret                        | APPLICATION_SECRET_NAME=application_settings        	| use within project unique secret name to be created and used by CLOUDBUILD and CLOUDRUN resources      	|
| roles/secretmanager.secretAccessor  |         	| on APPICATION_SECRET_NAME secret, assigned to cloud build and cloud run service accounts,<br> on PASSWORD_SECRET_NAME assigned to cloud build        	|
| roles/cloudsql.client           |         	| required by cloud build service account        	|
| roles/run.admin                 |         	| required by cloud build service account       	|
| roles/iam.serviceAccountUser    |         	| required by cloud build service account        	|

## Varialbes
List of Variables created and used in scritps are:
| VARIABLES                   	| Details 	|
|-----------------------------	|---------	|
| PROJECT_ID                	| Project Id in which we well create this deployment        	|
| REGION                      	| Region in which resources like bucket, sql instance will be created        	|
| SQL_INSTANCE_ID           	| Within in Project unique sql instance name, which haven't beeen used before        	|
| PASSWORD                      | SQL Instance user password        	|
| PROJECTNUM                 	| Porject Number of current PROJECT_ID        	|
| CLOUDBUILD                 	| Cloud Build service account        	|
| CLOUDRUN                     	| Cloud Run service account        	|

## API's  
We will need following apis to perfrom deplpoyment.  
| API Name          	| Service                      	| Details 	|
|-------------------	|------------------------------	|---------	|
| Cloud Sql         	| sql-component.googleapis.com 	|         	|
| Cloud Sql Admin   	| sqladmin.googleapis.com      	|         	|
| Cloud Run         	| run.googleapis.com           	|         	|
| Cloud Build       	| cloudbuild.googleapis.com    	|         	|
| Secret Manager    	| secretmanager.googleapis.com 	|         	|
| Cloud Compute     	| compute.googleapis.com       	|         	|
| Cloud Source Repo 	| sourcerepo.googleapis.com    	|         	|

## Deploying Django on Cloud Run  
#### *FOR DEPLOYING WITH DEFAULT RESOURCE NAMES, EXECUTE .sh SCRIPTS (IT MAY CAUSE CONFLICT IN RESOURCE NAMES), FOR DEPLOYMENT WITH CUSTOM RESOURCE NAMES RUN THE COMMANDS MENTIONED (EXCEPT source ./\*.sh)*  
## 1. Configure Project  
If you are using cloud sdk in local machine then run:
```
gcloud init
```
to authorize the gcloud to use your account, and follow the steps to create (or/and select)  
desired project. Or login to gcp cosole and select/create desired project from drop down.
use:
```
gcloud config list
```
to se if correct project configurations are set.  
_From now on we will perfrom all steps on local machine. but you can follow same steps in cloud shell in gcp console_  


## 2. Initialize PROJECT_ID,REGION and Enable API'S  
Run the script init.sh to configure the project, set the PROJECT_ID and REGION variables accordingly.  
use command:
```
source ./init.sh
```  
*note that we are using source to run our script, so that it runs within current shell and any*   
*variables intialized by script can be used in subsequent executions*   



__or run the following commands:__  
to set PROJECT_ID and REGION and to to confirm that you are authenticated and set project id.  
"if you have used `gcloud init` use 2nd method.  
  
_1st:_
```
PROJECT_ID=wproject-id
REGION=us-central1
gcloud auth list
gcloud config set project $PROJECT_ID
```
  
_2nd:_  
alternatively if you have used gcloud init to configure your project use following commands to intialize  
PROJECT_ID and REGION
```
PROJECT_ID=$(gcloud config get-value core/project)
REGION=$(gcloud config get-value compute/region)
```  
  
Now moving on to enabling apis. Run:   
```
gcloud services enable \
  run.googleapis.com \
  sql-component.googleapis.com \
  sqladmin.googleapis.com \
  compute.googleapis.com \
  cloudbuild.googleapis.com \
  secretmanager.googleapis.com
```



## 3. Create SQL Instance, Database and User  

You can execute create_database.sh using `source ./create_database.sh`  
1) This script will create Network peering for private network
2) Then will initialize a private SQ instance
3) Once created it will store all the variable for DB in .env file. 
which will initialize a private SQL_INSTANCE_ID, then create sql instance, then create database, then create 
user. And move on to next step.

Alternatively you can run following commands:  
Create sql postgres instance:
For __*SQL_INSTANCE_NAME*__ refer to table for variables on top.

```
#Password for DB Instance
DBPASS="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 30 | head -n 1)"

```
#create vpc-peering for private network

gcloud compute addresses create google-managed-services-default \
--global \
--purpose=VPC_PEERING \
--prefix-length=16 \
--network=default

gcloud services vpc-peerings connect \
--service=servicenetworking.googleapis.com \
--ranges=google-managed-services-default \
--network=default \
--project=$PROJECT_ID

```
# create sql postgers instance
PROJECT_ID=wproject-id
REGION=us-central1
SQL_INSTANCE_ID=myinstance
gcloud beta sql instances create myinstance --no-assign-ip --project $PROJECT_ID \
--network=default --root-password=$DBPASS  --database-version  POSTGRES_13  --tier db-f1-micro --region $REGION

```
#env var for DB
echo DB_HOST=$( gcloud sql instances describe $SQL_INSTANCE_ID |grep ipAddress: | awk '{print $NF}') >>.env
echo DB_NAME=postgres >>.env
echo DB_USER=postgre>>.env
echo DB_PASS=$DBPASS >>.env
echo POSTGRES_DB=postgres >>.env
echo POSTGRES_USER=postgres >>.env
echo POSTGRES_PASSWORD=$DBPASS >>.env



## 5. Create configruation File (using Secret Manager):  
Before continuing with this step make sure you have followed all previous steps and
following environment variables have been initialized:
 1. PROJECT_ID
 2. REGION
 3. SQL_INSTANCE_ID
 4. REGION
 5. PASSWORD
Now we will add configurations. 
As before you can simply run `source ./secret.sh`  
or run following commands:  
Create configurations to be used by appilcation:
```
echo SECRET_KEY=\"$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)\" >> .env
echo DEBUG=\"True\" >> .env
```
Now we have stored configurations in file, use secret manager to create secret using this file.  
For __*APPLICATOIN_SECRET_NAME*__ refer to resources table.  
Go to myproject -> settings.py and on line 18 assign SETTINGS_NAME variable APPLICATION_SECRET_NAME. (default is application_settings)
```
gcloud secrets create APPLICATION_SECRET_NAME --data-file .env
gcloud secrets versions list APPLICATION_SECRET_NAME
rm .env 
```


## 6. Create IAM Roles Bindings  
Build is run by cloud build and then application is deployed to cloud run.  
We will assign following roles to different service account and secrets.  
Again simply run `source ./iam-binding.sh` or run the following commands.  
Intialize CLOUD_BUILD and CLOUD_RUN variables with the service account.  
```
PROJECTNUM=$(gcloud projects describe ${PROJECT_ID} --format 'value(projectNumber)')
CLOUDRUN=${PROJECTNUM}-compute@developer.gserviceaccount.com
CLOUDBUILD=${PROJECTNUM}@cloudbuild.gserviceaccount.com
```

Allow cloudbuild and cloudrun to access __*APPLICATION_SECRET_NAME*__ secret.  
For __*APPLICATION_SECRET_NAME*__ refer to resources table.   
```
gcloud secrets add-iam-policy-binding $APPLICATION_SECRET_NAME \
  --member serviceAccount:${CLOUDRUN} --role roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding $APPLICATION_SECRET_NAME \
  --member serviceAccount:${CLOUDBUILD} --role roles/secretmanager.secretAccessor
```
Allow cloudbuild to access PASSWORD_SECRET_NAME secret.  
For __*PASSWORD_SECRET_NAME*__ refer to resources table.  

Allow cloud build role of cloudsql.client  and run.admin
```
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${CLOUDBUILD} --role roles/cloudsql.client
```
```
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${CLOUDBUILD} --role roles/run.admin
```
Allow cloud build run.admin and role of cloud run service account user.  
```
gcloud iam service-accounts add-iam-policy-binding $CLOUDRUN \
  --member="serviceAccount:"${CLOUDBUILD} \
  --role="roles/iam.serviceAccountUser"
```



## 7. Deploye redis service on cloud run using Cloud Build  
Submit build to create and push container image and run migrations using cloudmigrate.yaml file.
For __*SERVICE_NAME*__ and __*IMAGE_NAME*__ refer to resources table.    
```
gcloud builds submit --config cloud-run-redis.yaml
```
Update URL for redis in app/app/settings.py
```
private_redis=$(gcloud run services describe redis-private --platform managed --region  $REGION |grep URL |awk '{print $NF}')
```
sed -i "s|REDIS_URL|"$private_redis"|g" "app/app/settings.py"

## 7. Deploye redis service on cloud run using Cloud Build 

Now build & deploy django app to cloud run.
```
gcloud builds submit --config cloudrun_deployment.yaml --substitutions _REGION=$REGION,_SQL_INSTANCE_ID=my-instance,_SERVICE_NAME=my-app,_IMAGE_NAME=my-app,_MY_VPC_CONNECTOR=my-vpc-connextor,_PORT=8000
```

The successfull build will return url of the service in response.

