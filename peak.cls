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
    /**
    *Posts the payload in the message parameter to Slack channel defined in channel argument
    * using a queueable method
    *@param channel     Channel name. This is a custom metadata defined in the Org with
    *                   a related webhook. This is where the message will be posted
    *@param message     A stringified message of the whole payload to be posted to Slack.
    *                   The message must meet Slack formatting requirements to be successful.
    *
    **/
    global static void postToSlack(String channel, String message){
        //get slack channel by name from custom metadata
        Slack_Channels__mdt[] channelMetadata = [select developername, webhook__c from Slack_Channels__mdt where developername = :channel];
        if(channelMetadata.size() <= 0)return;
        String webhook = channelMetadata[0].webhook__c;
        // create http request with the webhook
        queueableCallout qcall = new queueableCallout(webhook,'POST',message,'application/json');
        //send request
        Id jobId = System.enqueueJob(qcall);
        system.debug('jobid '+jobId);
    }
    /**
    *General Queueable Class to help with a callout.
    **/
    class queueableCallout implements system.Queueable,Database.allowsCallouts{
        String Url;
        String method;
        String body;
        String contentType;

        public queueableCallout(String url, String method, String body, String contentType){
            this.url = url;
            this.method = method;
            this.body = body;
            this.contentType = contentType;
        }

        //public queueableCallout(Object req){
            //https://salesforce.stackexchange.com/questions/159934/i-want-to-pass-an-httprequest-object-to-a-class-that-implements-the-queueable-in
            //this.genreq = req;
        //}

        public void execute(QueueableContext qtc){
            HttpRequest req = new HttpRequest();
            req.setEndpoint(url);
            req.setMethod(method);
            req.setBody(body);
            req.setHeader('ContentType', contentType);
            Http http = new http();
            HttpResponse res = http.send(req);
        }
    }
    /**
    *Converts an Exception Message into a Message formatted for Slack. This data
    *is formatted-
    *   Stack Trace String
    *   Type Name
    *   Message
    *   Context User
    *@param Exception   Generic Exception object that needs to be formatted
    **/
    global static Map<String,Object> slackifyException(Exception e){
        Map<string,object> body = new Map<String,object>();
        object[] attachments;
        object[] fields;

        fields = new Object[]{
            new Map<String,Object>{
                'title' => 'Stack Trace',
                'value' => e.getStackTraceString(),
                'short' => false
            },
            new Map<String,Object>{
                'title' => 'Context User',
                'value' => UserInfo.getUserName(),
                'short' => true
            },
            new Map<String,Object>{
                'title' => 'Environment',
                'value' => 'Dev Org',
                'short' => true
            }
        };

        attachments = new Object[]{
            new Map<String,Object>{
                'title' => e.getTypeName(),
                'text' => '`'+e.getMessage()+'`',
                'color' => '#ff0000',
                'fields' => fields,
                'mrkdwn_in' => new String[]{'text'}
            }
        };

        body.put('text','Exception Alert !');
        body.put('attachments',attachments);

        return body;

    }

    

}