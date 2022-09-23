/**
 * @description       : 
 * @author            : Joseph Forbes
 * @group             : 
 * @last modified on  : 11-18-2020
 * @last modified by  : Joseph Forbes
 * Modifications Log 
 * Ver   Date         Author          Modification
 * 1.0   11-18-2020   Joseph Forbes   Initial Version
**/
// Object:          EnvVariable class
// Business Unit:   All
// Created:         07/20/2018
// Description:
//      Retrieves data from the Environment Variable Custom Settings
//      
// :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
// Change History
// Date             Developer           Work Item       Description
// ---------------------------------------------------------------------------------------------------
// ??/??/2018       John Ellison        ??              Created
// 02/22/2019		John Ellison		31350			Updated to Cache Data
// :::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
public class EnvVariable {
    private static Map<String,Env_Variable__c> envMap = new Map<String,Env_Variable__c>();
    @AuraEnabled(cacheable=true)
    public static String getValue(String varName){
        if(envMap.size() == 0) buildMap();
        Env_Variable__c envVar = envMap.get(varName);
        if(envVar == null) return null;
        
        // check if there's a user-specific setting
        try{
            if(envVar.User_Switch_Active__c && envVar.Users__c.contains(UserInfo.getUserId())){
                //user-specific check is active and current user is in it; take user-specific value
                return envVar.User_Specific_Value__c;
            }
        }catch(Exception e){}
        
        // check standard setting
        if(envVar.Active__c){
            return envVar.Value__c;
        }
        
        // else, return null
        return null;
    }
    
    private static void buildMap(){
        for(Env_Variable__c env : [SELECT Name, Value__c, Active__c, User_Specific_Value__c, User_Switch_Active__c, Users__c 
                                     FROM Env_Variable__c]){
        	envMap.put(env.Name, env);
        }
    }
}