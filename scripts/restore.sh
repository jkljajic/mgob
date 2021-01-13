#!/bin/bash
export connectionString=$(cat /config/TFBank_mongo_backup.yml  | grep connectionString: | awk '{print $2}')
export containerName=$(cat /config/TFBank_mongo_backup.yml  | grep containerName: | awk '{print $2}')
export mongodbUri=$(cat /config/TFBank_mongo_backup.yml  | grep uri: | awk '{print $2}')

select brand in exit $(az storage blob list -c $containerName --connection-string=$connectionString --query "[].{name:name}" --output tsv)
do 
    if [ "$brand" == "exit" ]
    then
        break;    
    fi
    archivePath=/tmp/$(basename "$brand")
    az storage blob download  -c $containerName --connection-string=$connectionString --file $archivePath  --name $brand

    mongorestore  --gzip --uri=$mongodbUri --archive=$archivePath
    break
done




 