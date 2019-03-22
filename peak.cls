global class peak{

    Static Map<String, Schema.DescribeSObjectResult> objectDescMap;
    /**
    *Creates a Map of Record Id and related Set of ContentVersion Ids
    *for the list of Record Ids passed as argument
    *
    * @param recordIdSet    the set of sobject record ids
    *
    * @return               Map of Record Ids that were passed in as 
    *                       arguments and their related ContentVersion
    *                       Ids in a Set. Use this set to query for base64
    *                       data.
    **/
    global static Map<Id,Set<Id>> getRelatedFileIds(Set<Id> recordIdSet){
        //Map of file Id and related ContentVersionIds
        Map<Id,Set<Id>> contentIdMap = new Map<Id,Set<Id>>();
        //query to find all contentversions
        for(ContentDocumentLink c: [select LinkedEntityId, contentdocument.LatestPublishedVersionId from ContentDocumentLink where LinkedEntityId in :recordIdSet]){
            if(contentIdMap.containsKey(c.LinkedEntityId)){
                Set<Id> tempset = contentIdMap.get(c.LinkedEntityId);
                tempset.add(c.contentdocument.LatestPublishedVersionId);
            }else{
                Set<Id> tempset = new Set<id>();
                tempset.add(c.contentdocument.LatestPublishedVersionId);
                contentIdMap.put(c.LinkedEntityId,tempset);
            }
        }
        return contentIdMap;
    }
    /**
    *Creates a String query with all the fields of the sObject passed in
    *as parameter.
    *
    *@param objName     API name of object with namespace prefix(if packaged)
    *
    *@return            Generated query in a String format. Add any where clause
    *                   after the result of this method
    *          
    **/
    global static String getAllFieldQuery(String objName){
        String query = '';
        if(objectDescMap == null) objectDescMap = new Map<String, Schema.DescribeSObjectResult>();
        if(!objectDescMap.containsKey(objName)){ 
            for(Schema.DescribeSObjectResult res : Schema.describeSObjects(new String[]{objName})){
                objectDescMap.put(res.getName(),res);
            }
        }

        Map<String, Schema.SObjectField> FMap = objectDescMap.get(objName).fields.getMap();
        for(String f : Fmap.keyset()){
            query += f+',';
        }
        query = query.removeEnd(',');
        query = 'select '+query+' from '+objName;
        return query;
    }

}