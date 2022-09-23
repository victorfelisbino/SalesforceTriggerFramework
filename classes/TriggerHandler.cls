/**
 * @File Name          : TriggerHandler.cls
 * @Description        : Generic/Dynamic/Synergy/Web 2.0 Trigger Logic
 * @Author             : John Ellison
 * @Group              : 
 * @Last Modified By   : Joseph Forbes
 * @Last Modified On   : 11-12-2020
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0       02/15/2018      John Ellison           Created
 * 1.1       07/18/2018      John Ellison           Included Change Filter Logic
 * 1.2       07/02/2019      John Ellison           Leverage Logger + More
 * 1.3       09/25/2019      John Ellison           More Logging for Phantom Errors
**/
global class TriggerHandler  {
    public static Map<String, List<Trigger_Detail__c>> triggerMap;
    public static Map<Id, List<Trigger_Detail__c>> fieldFilters;
    public static Map<Id, List<String>> recTypeFilters;
    public static Map<Id, List<Trigger_Detail__c>> changeFilters;

    public static Map<String,List<SObject>> sObjectInsert = new Map<String,List<SObject>>();
    public static Map<String,List<SObject>> sObjectUpdate = new Map<String,List<SObject>>();
    public static Map<String,List<SObject>> sObjectDelete = new Map<String,List<SObject>>();

    public static Set<String> fireList = new Set<String>();
    public static Map<String,Integer> fireCount = new Map<String,Integer>();
    public static Map<String,Set<Id>> validCount = new Map<String,Set<Id>>();

    public static void handle(List<SObject> oldTriggerList, List<SObject> newTriggerList, String objName, String methodName){
        List<Trigger_Detail__c> triggers = TriggerHandler.getTriggers(objName, methodName);
        if(triggers == null || triggers.size() == 0) return;
        Map<Id,SObject> oldMap = TriggerHandler.buildOldMap(oldTriggerList);
        for(Trigger_Detail__c trigDetail : triggers){
            System.debug('Trigger Execution: ' + objName + ' - ' + methodName + ' - ' + trigDetail.Class_Name__c);
            try{
                TriggerHandler.CustomTrigger trig = TriggerHandler.dynMap(trigDetail.Class_Name__c);
                trig.execute(trigDetail, oldMap, newTriggerList);
            }catch(Exception e){
                Log.error('Trigger Exception: ' + '[' + trigDetail.Class_Name__c + ']', e, 'Trigger');
            }
        }
        TriggerHandler.commitChanges(objName, methodName);
    }

    public static List<Trigger_Detail__c> getTriggers(String objName, String methodName){
        String isMethodName = methodName + '__c';

        try{
            if(triggerMap == null) buildCache();
            List<Trigger_Detail__c> results = new List<Trigger_Detail__c>();
            if(triggerMap.get(objName) == null) return results;
            for(Trigger_Detail__c trig : triggerMap.get(objName)){
                if(trig.get(isMethodName) == false) continue;
                if(trig.Skip_Users_List__c != null && trig.Skip_Users_List__c.contains(UserInfo.getUserId())) continue;
                if(trig.Active__c == false){
                    if(trig.Run_Users_List__c == null) continue;
                    if(trig.Run_Users_List__c != null && trig.Run_Users_List__c.containsNone(UserInfo.getUserId())) continue;
                }
                results.add(trig);
            }
            return results;
        }catch(Exception ex){
            Log.error('No Triggers Found ' + '[' + objName + '/' + methodName + ']', ex, 'Trigger');
            return null;
        }
    }

    private static void buildCache(){
        triggerMap     = new Map<String, List<Trigger_Detail__c>>();
        fieldFilters   = new Map<Id, List<Trigger_Detail__c>>();
        recTypeFilters = new Map<Id, List<String>>();
        changeFilters  = new Map<Id, List<Trigger_Detail__c>>();

        List<Trigger_Detail__c> records = [SELECT Id, RecordTypeId, Name, Active__c, Description__c, Object__c, Parent_Trigger__c,
                                                  isAfterInsert__c, isAfterUpdate__c, isBeforeUpdate__c, isBeforeInsert__c,
                                                  isBeforeDelete__c, Class_Name__c,
                                                  Field_Name__c, Field_Value__c, Record_Type_Name__c,
                                                  Run_Users_List__c, Skip_Users_List__c, Change_Filters__c,
                                                  ignore_blank_initial_values__c, ignore_blank_updates__c
                                           FROM Trigger_Detail__c ORDER BY Sequence__c];
        if(records.size() == 0) return;

        for(Trigger_Detail__c rec : records){
            if(rec.RecordTypeId == Global_Util.getRecordType('Trigger_Detail__c', 'Trigger').Id){
               if(triggerMap.get(rec.Object__c) == null) triggerMap.put(rec.Object__c, new List<Trigger_Detail__c>());
               triggerMap.get(rec.Object__c).add(rec);

            }else if(rec.RecordTypeId == Global_Util.getRecordType('Trigger_Detail__c', 'Record_Type_Filter').Id){
                if(recTypeFilters.get(rec.Parent_Trigger__c) == null) recTypeFilters.put(rec.Parent_Trigger__c, new List<String>());
                if(rec.Active__c == true) recTypeFilters.get(rec.Parent_Trigger__c).add(rec.Record_Type_Name__c);

            }else if(rec.RecordTypeId == Global_Util.getRecordType('Trigger_Detail__c', 'Field_Filter').Id){
                if(fieldFilters.get(rec.Parent_Trigger__c) == null) fieldFilters.put(rec.Parent_Trigger__c, new List<Trigger_Detail__c>());
                if(rec.Active__c == true) fieldFilters.get(rec.Parent_Trigger__c).add(rec);
            }else if(rec.RecordTypeId == Global_Util.getRecordType('Trigger_Detail__c', 'Change_Filter').Id){
                if(changeFilters.get(rec.Parent_Trigger__c) == null) changeFilters.put(rec.Parent_Trigger__c, new List<Trigger_Detail__c>());
                if(rec.Active__c == true) changeFilters.get(rec.Parent_Trigger__c).add(rec);
            }
        }
    }

    public static Boolean hasFired(String name){
        if(fireList.contains(name)) return true;
        else return false;
    }

    public static void setFired(String name){
        if(!fireList.contains(name)) fireList.add(name);
        Integer cnt = fireCount.get(name);
        if(cnt == null) fireCount.put(name, 1);
        else fireCount.put(name, cnt + 1);
    }

    public static void resetFired(String name){
        if(fireList.contains(name)) fireList.remove(name);
        fireCount.put(name, 0);
    }
    
    public static Integer getFiredCount(String name){
        Integer cnt = fireCount.get(name);
        if(cnt == null) return 0;
        else return cnt;
    }
    
    public static void setSObjectValid(String name, Id sId){
        Set<Id> ids = validCount.get(name);
        if(ids == null) ids = new Set<Id>();
        ids.add(sId);
        validCount.put(name, ids);
    }
    
    public static Boolean wasValid(String name, Id sId){
        Set<Id> ids = validCount.get(name);
        if(ids == null) return false;
        else if(ids.contains(sId)) return true;
        else return false;
    }

    public static Boolean isRecordValid(Trigger_Detail__c triggerDetails, SObject obj){
        if(!checkRecordType(triggerDetails, obj)) return false;
        if(!checkFieldFilters(triggerDetails, obj)) return false;
        if(!Trigger.isInsert){
        	if(!checkChangeFilters(triggerDetails, obj, Trigger.oldMap.get(obj.Id))) return false;   
        }
        if(obj.Id != null) setSObjectValid(triggerDetails.Class_Name__c, obj.Id);
        return true;
    }

    //this method needs to go away at some point, but until then -- here it lies
    public static Boolean isRecordValid(Trigger_Detail__c triggerDetails, SObject objNew, SObject objOld){
        return isRecordValid(triggerDetails, objNew);
    }

    private static Boolean checkRecordType(Trigger_Detail__c triggerDetails, SObject obj){
        // TRUE Response = Continue and Execute Trigger Logic for Record
        // FALSE Response = Stop and DO NOT Execute Trigger Logic for Record
        List<String> recTypes = recTypeFilters.get(triggerDetails.Id);

        Id recordTypeId;
        String recTypeName = '';
        try{
            recordTypeId = Id.valueOf(String.valueOf(obj.get('RecordTypeId')));
            recTypeName = Global_Util.getRecordTypeFromID(triggerDetails.Object__c, recordTypeId).Name;
            if(recTypes != null && recTypes.size() > 0 && recTypes.contains(recTypeName) == false) return false;
        }catch(Exception e){
            System.debug('Record Type issues: ' + e.getMessage());
            if(e.getMessage().contains('Invalid field')) return true;
            return false;
        }

        return true;
    }

    private static Boolean checkFieldFilters(Trigger_Detail__c triggerDetails, SObject obj){
        // TRUE Response = Continue and Execute Trigger Logic for Record
        // FALSE Response = Stop and DO NOT Execute Trigger Logic for Record
        List<Trigger_Detail__c> fields = fieldFilters.get(triggerDetails.Id);
        if(fields != null){
            String objValue;
            for(Trigger_Detail__c field : fields){
                try{
                    objValue = String.valueOf(obj.get(field.Field_Name__c));
                }catch(Exception e){
                    continue;
                }
                try{
                    if(field.Field_Value__c == 'null'){
                        if(objValue == null || String.isBlank(objValue)) continue;
                        else return false;
                    }else if(field.Field_Value__c == '!null'){
                        if(objValue != null) continue;
                        else return false;
                    }else if(field.Field_Value__c.contains(';')){
                        if(objValue != null && field.Field_Value__c.contains(objValue)) continue;
                        else return false;
                    }else{
                        if(objValue == field.Field_Value__c) continue;
                        else return false;
                    }
                }catch(Exception e){
                    Log.error('Field Filter Failure: ' + 
                            '[' + obj.Id + 
                            '/' + field.Field_Name__c +
                            '/' + field.Field_Value__c + 
                            '/' + objValue +
                            ']', e, 'Trigger');
                    return false;
                }
            }
        }

        return true;
    }

    private static Boolean checkChangeFilters(Trigger_Detail__c triggerDetails, SObject objNew, SObject objOld){
        // TRUE  Response = Continue and Call Trigger --> Conditions Passed
        // FALSE Response = Stop and Do Not Call Trigger --> Conditions Failed

        List<Trigger_Detail__c> changes  = changeFilters.get(triggerDetails.Id);
        Boolean somethingChanged = false;

        if(changes == null) somethingChanged = true;
        if(changes != null){
            String objValueNew;
            String objValueOld;
            for(Trigger_Detail__c change : changes){
                try{
                    objValueNew = String.valueOf(objNew.get(change.Field_Name__c));
                    try{
                        objValueOld = String.valueOf(objOld.get(change.Field_Name__c));
                    }catch(Exception e){}
                }catch(Exception e){
                    System.debug('Field Validation Exception: ' + e.getMessage());
                    System.debug(e.getStackTraceString());
                    continue;
                }
                

                // no change; we require all of these to have a change --> failure/stop
                if(objValueOld == objValueNew && triggerDetails.Change_Filters__c == 'All Change Filters') return false;

                // technically a change happened
                if(objValueOld != objValueNew){
                    // we don't consider a old blank value to be a change
                    if(change.ignore_blank_initial_values__c){
                        // we require all fields to change, this did not change --> failure/stop
                        if(triggerDetails.Change_Filters__c == 'All Change Filters' && String.isBlank(objValueOld)) return false;
                        // we require just one field to change, this did not change --> move to next field
                        if(triggerDetails.Change_Filters__c == 'Any Change Filters' && String.isBlank(objValueOld)) continue;
                        // the field changed; All or Any -- it doesn't matter
                        somethingChanged = true;
                        continue;
                    }

                    // we don't consider a new blank value to be a change
                    if(change.ignore_blank_updates__c){
                        // we require all fields to change, this did not change --> failure/stop
                        if(triggerDetails.Change_Filters__c == 'All Change Filters' && String.isBlank(objValueNew)) return false;
                        // we require just one field to change, this did not change --> move to next field
                        if(triggerDetails.Change_Filters__c == 'Any Change Filters' && String.isBlank(objValueNew)) continue;
                        // the field changed; All or Any -- it doesn't matter
                        somethingChanged = true;
                        continue;
                    }

                    // we require just one field to change and this field definitely changed --> success/stop
                    if(triggerDetails.Change_Filters__c == 'Any Change Filters') return true;
                    // we require all fields to change and this changed --> move to next field
                    somethingChanged = true;
                }
            }
        }

        return somethingChanged;
    }

    public static Map<Id, SObject> buildOldMap(List<SObject> oldTriggerList){
        //return Trigger.oldMap;
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        if(oldTriggerList != null){
            for(SObject obj : oldTriggerList){
                oldMap.put(obj.Id, obj);
            }
        }
        return oldMap;
    }

    public static TriggerHandler.CustomTrigger dynMap(String className){
        Type newType = Type.forName(className);
        if (newType != null) return (TriggerHandler.CustomTrigger) newType.newInstance();
        else return null;
    }

    public static void commitChanges(String objName, String methodName){
        //INSERT
        try{
            List<SObject> insList = sObjectInsert.get(objName);
            sObjectInsert.put(objName, null);
            if(insList != null && insList.size() > 0) insert insList;

        }catch(Exception eI){
            System.debug('Exception inserting records: ' + eI.getMessage());
            System.debug(eI.getStackTraceString());
        }

        //UPDATE
        try{
            List<SObject> updList = sObjectUpdate.get(objName);
            sObjectUpdate.put(objName, null);
            if(updList != null && updList.size() > 0) update updList;
        }catch(Exception eU){
            System.debug('Exception updating records: ' + eU.getMessage());
            System.debug(eU.getStackTraceString());
        }

        //DELETE
        try{
            List<SObject> delList = sObjectDelete.get(objName);
            sObjectDelete.put(objName, null);
            if(delList != null && delList.size() > 0) delete delList;
        }catch(Exception eD){
            System.debug('Exception deleting records: ' + eD.getMessage());
            System.debug(eD.getStackTraceString());
        }
    }

    public static void addInsertObject(String objName, SObject obj){
        if(sObjectInsert.get(objName) == null) sObjectInsert.put(objName, new List<SObject>());
        sObjectInsert.get(objName).add(obj);
    }

    public static void addUpdateObject(String objName, SObject obj){
        if(sObjectUpdate.get(objName) == null) sObjectUpdate.put(objName, new List<SObject>());
        sObjectUpdate.get(objName).add(obj);
    }

    public static void addDeleteObject(String objName, SObject obj){
        if(sObjectDelete.get(objName) == null) sObjectDelete.put(objName, new List<SObject>());
        sObjectDelete.get(objName).add(obj);
    }

    global interface CustomTrigger
    {
        void execute(Trigger_Detail__c triggerDetails, Map<Id,SObject> oldObjectMap, List<SObject> newObjectList);
    }

}