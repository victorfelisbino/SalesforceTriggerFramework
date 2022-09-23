public class LeadTriggerHandler {
    private static final String objName = 'Lead';
     /**********************************************************************
    * Before Insert 
    **********************************************************************/
    public static void isBeforeInsert(List<Lead> oldTriggerList, List<Lead> newTriggerList){
        TriggerHandler.handle(oldTriggerList, newTriggerList, objName, 'isBeforeInsert');
    }
    /**********************************************************************
    * Before update 
    **********************************************************************/
    public static void isBeforeUpdate(List<Lead> oldTriggerList, List<Lead> newTriggerList){
        TriggerHandler.handle(oldTriggerList, newTriggerList, objName, 'isBeforeUpdate');
    }
    /**********************************************************************
    * After Insert 
    **********************************************************************/
    public static void isAfterInsert(List<Lead> oldTriggerList, List<Lead> newTriggerList){
        TriggerHandler.handle(oldTriggerList, newTriggerList, objName, 'isAfterInsert');
    }
    /**********************************************************************
    * After Update
    **********************************************************************/
    public static void isAfterUpdate(List<Lead> oldTriggerList, List<Lead> newTriggerList){
        TriggerHandler.handle(oldTriggerList, newTriggerList, objName, 'isAfterUpdate');
    }
}