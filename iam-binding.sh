#name of secret
APPLICATION_SECRET_NAME=application_settings

PROJECTNUM=$(gcloud projects describe ${PROJECT_ID} --format 'value(projectNumber)')
CLOUDRUN=${PROJECTNUM}-compute@developer.gserviceaccount.com
CLOUDBUILD=${PROJECTNUM}@cloudbuild.gserviceaccount.com

# allow permissions
gcloud secrets add-iam-policy-binding $APPLICATION_SECRET_NAME \
  --member serviceAccount:${CLOUDRUN} --role roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding $APPLICATION_SECRET_NAME \
  --member serviceAccount:${CLOUDBUILD} --role roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding admin_password \
  --member serviceAccount:${CLOUDRUN} --role roles/secretmanager.secretAccessor

gcloud secrets add-iam-policy-binding admin_password \
  --member serviceAccount:${CLOUDBUILD} --role roles/secretmanager.secretAccessor

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${CLOUDBUILD} --role roles/cloudsql.client

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${CLOUDBUILD} --role roles/run.admin

gcloud iam service-accounts add-iam-policy-binding $CLOUDRUN \
  --member="serviceAccount:"${CLOUDBUILD} \
  --role="roles/iam.serviceAccountUser"