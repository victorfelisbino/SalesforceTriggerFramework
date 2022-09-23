trigger LeadTrigger on Lead (before insert,before update,after insert,after update) {
    if(Trigger.isBefore){
        if(Trigger.isInsert){
            LeadTriggerHandler.isBeforeInsert(Trigger.old, Trigger.new);
        }
        if(Trigger.isUpdate){
            LeadTriggerHandler.isBeforeUpdate(Trigger.old, Trigger.new);
        }
    }else if(Trigger.isAfter){
        if(Trigger.isInsert){
            LeadTriggerHandler.isAfterInsert(Trigger.old, Trigger.new);
        }
        if(Trigger.isUpdate){
            LeadTriggerHandler.isAfterUpdate(Trigger.old, Trigger.new);
        }
    }
    
}