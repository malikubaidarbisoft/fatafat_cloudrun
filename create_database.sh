#Password for DB Instance
DBPASS="$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 30 | head -n 1)"

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

# create sql postgers instance
SQL_INSTANCE_ID=myinstance
gcloud beta sql instances create myinstance --no-assign-ip --project $PROJECT_ID \
--network=default --root-password=$DBPASS  --database-version  POSTGRES_13  --tier db-f1-micro --region $REGION

# create a database inside sql instance
# gcloud sql databases create mydatabase --instance $SQL_INSTANCE_ID

# # create a new user for instance
# PASSWORD=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w 50 | head -n 1)
# gcloud sql users create djuser --password $PASSWORD --instance $SQL_INSTANCE_ID

#env var for DB
echo DB_HOST=$( gcloud sql instances describe $SQL_INSTANCE_ID |grep ipAddress: | awk '{print $NF}') >>.env
echo DB_NAME=postgres >>.env
echo DB_USER=postgre>>.env
echo DB_PASS=$DBPASS >>.env

echo POSTGRES_DB=postgres >>.env
echo POSTGRES_USER=postgres >>.env
echo POSTGRES_PASSWORD=$DBPASS >>.env