/**
 * @File Name          : Global_Util.cls
 * @Description        : 
 * @Author             : Bob Sanders
 * @Group              : 
 * @Last Modified By   : Bob Sanders
 * @Last Modified On   : 5/5/2020, 10:20:30 PM
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    5/1/2020   Bob Sanders     Initial Version
**/
// Object:          Global_Util class
// Business Unit:   All
// Created:         05/02/2017
// Description:
//      Global Utility Options - Series of Static Methods
//      
// :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
// Change History
// Date             Developer           Work Item       Description
// ---------------------------------------------------------------------------------------------------
// 05/02/2017       Vicky Felisbino		?				Created
// 02/22/2019		John Ellison		31350			Updated to Reduce SOQL Queries
// :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
public class Global_Util {
    public class RecordTypeException extends Exception {}
    private static Map<String,Map<String,RecordType>> recordTypeMap;
    private static Map<String,Id> workTypeIDMap;
    private static Map<String,Profile> profileMap;
    
    public static final string ERROR_RECTYPE_NOT_FOUND = 'The requested record type was not found';
    public static final string RESPONSE_NO_AVAILABLE_RECORDTYPE = 'There are no record types available.';
    
    @future
    static public void addChatterFollower(Id userId, Id objectToFollowId) {
        EntitySubscription e = new EntitySubscription();
        e.subscriberId = userId;
        e.parentId = objectToFollowId;
        Database.insert(e,false);
    }
    
    @AuraEnabled
    public static RecordType getRecordType(String sObjectName, String name) {
        if(recordTypeMap == null) buildRecordTypeMap();
        RecordType returnValue;
        returnValue = recordTypeMap.get(sObjectName).get(name);
        if(returnValue == null) throw new RecordTypeException(ERROR_RECTYPE_NOT_FOUND);
        return returnValue;
    }
    
    public static String getCurrentUserProfileName(){
        if(profileMap == null) buildProfileMap();
        Profile pro;
        try{
            pro = profileMap.get(UserInfo.getProfileId());
        }catch(DmlException ex){
            System.debug('User Profile Not Found: ' + ex.getMessage());
            return '';
        }
        return pro.Name;
    }

    @AuraEnabled(cacheable=true)
    public static RecordType getRecordTypeFromID(String sObjectName, String id) {
        if(recordTypeMap == null) buildRecordTypeMap();
        RecordType returnValue;
        returnValue = recordTypeMap.get(sObjectName).get(id);
        if(returnValue == null) throw new RecordTypeException(ERROR_RECTYPE_NOT_FOUND);
        return returnValue;
    }
    
    public static void postUpdatesToChatter(String objectId, String message){

        try{
            FeedItem post = new FeedItem();
            post.ParentId = objectId;
            post.Body = message;
            insert post;
        }catch(Exception e){
            system.debug('Error posting to chatter. objectid: '+objectId+' error: '+e.getMessage());
        }
    }

    public static void cloneFeedItemToParent(String parentRecordId, FeedItem cloneThisItem){

        try{
            FeedItem newFeedItemOnParent = cloneThisItem.clone(false,false,true,false);
            newFeedItemOnParent.ParentId = parentRecordId;
            insert newFeedItemOnParent;
        }catch(Exception e){
            system.debug('Error posting to chatter. parentRecordId: '+parentRecordId+' error: '+e.getMessage());
        }
    }
    
    // LAZY LOAD METHODS BELOW
    public static Id getWorkTypeIdFromName(String name) {
        if(workTypeIDMap == null) buildWorkTypeMap();
        return workTypeIDMap.get(name);
    }
    
    private static void buildRecordTypeMap(){
        recordTypeMap = new Map<String,Map<String,RecordType>>();
        for(RecordType r : [SELECT BusinessProcessId,DeveloperName,IsActive,Name,SobjectType FROM RecordType]) {
            Map<String,RecordType> recordTypeInnerMap = recordTypeMap.get(r.SobjectType);
            
            if(recordTypeInnerMap == null) {
                recordTypeInnerMap = new Map<String,RecordType>();
            }
            
            recordTypeInnerMap.put(r.DeveloperName,r);
            recordTypeInnerMap.put(r.Id,r);
            recordTypeMap.put(r.SobjectType,recordTypeInnerMap);
        }
    }
    
    private static void buildWorkTypeMap(){
        workTypeIDMap = new Map<String,Id>();
        for(WorkType wt : [SELECT Id, Name FROM WorkType]){
            workTypeIDMap.put(wt.Name, wt.Id);
        }
    }
    
    private static void buildProfileMap(){
        profileMap = new Map<String,Profile>();
        for(Profile pro : [SELECT Name FROM Profile]){
            profileMap.put(pro.Name, pro);
            profileMap.put(pro.Id, pro);
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<RecordTypeInfo> getRecordTypesForCurrentUser(String objectTypeName, String limitRecordResults, Boolean isLWC){
        Map<String, Schema.SObjectType> globalDesc = Schema.getGlobalDescribe();
        Schema.SobjectType objType = globalDesc.get(objectTypeName);

        Schema.DescribeSObjectResult objRecord = objType.getDescribe();
        List<Schema.RecordTypeInfo> recordTypeInfo = objRecord.getRecordTypeInfos();

        List<RecordTypeInfo> recInfo = new List<RecordTypeInfo>();

        if(!recordTypeInfo.isEmpty()){
            for(Schema.RecordTypeInfo rec : recordTypeInfo){
                RecordTypeInfo recTypeInfo = new RecordTypeInfo();
                if(rec.isAvailable()){
                    recTypeInfo.recordTypeName = rec.getName();
                    recTypeInfo.recordTypeDeveloperName = rec.getDeveloperName();
                    if(limitRecordResults == '' || limitRecordResults == null) recInfo.add(recTypeInfo);
                    else{
                        if(limitRecordResults.split(';').contains(rec.getDeveloperName())) recInfo.add(recTypeInfo);
                    }   
                }
            }
        }
        
        if(recInfo.isEmpty() && isLWC){
            AuraHandledException e = new AuraHandledException(RESPONSE_NO_AVAILABLE_RECORDTYPE);
            e.setMessage(RESPONSE_NO_AVAILABLE_RECORDTYPE);
            throw e;
        }
        else if(recInfo.isEmpty() && !isLWC){
            return null;
        }
        
        return recInfo;
    }

    public static List<String> getFieldNames(String SObjectType, String fieldType) {
      List<String> results = new List<String>();

      Map<String,SObjectField> objectFields = Schema.getGlobalDescribe().get(SObjectType).getDescribe().fields.getMap(); 
      for(String fieldName: objectFields.keySet()){
        Schema.DescribeFieldResult field = objectFields.get(fieldName).getDescribe();
        if(fieldType == 'reference' && String.valueOf((field.getType())) == 'REFERENCE'){
          results.add(field.getName()); 
        }
        if(fieldType == 'custom' && field.isCustom()){
          results.add(field.getName());
        }
        else if(fieldType == null){
          results.add(field.getName());
        }
      }

      return results;
    }

    @AuraEnabled(cacheable=true)
    public static RecordType getObjectRecordType(String recordType, String objectTypeName){
        return getRecordType(objectTypeName, recordType);
    }

    public class RecordTypeInfo{
        @AuraEnabled public string recordTypeName {get;set;}
        @AuraEnabled public string recordTypeDeveloperName {get;set;}
    }
}