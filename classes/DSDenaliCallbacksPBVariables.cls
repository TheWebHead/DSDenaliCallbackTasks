/***************************************************
Anthony Kelly, Salesforce Developer 5/27/2020

Brief Description: DialSource Denali Set Callback Variables.
All of the required parameters for posting to the Callback
endpoint are accounted for.
****************************************************/
global class DSDenaliCallbacksPBVariables {
    @InvocableVariable(required=True)
    global String uid;
    @InvocableVariable(required=True)
    global String object_id;
    @InvocableVariable(required=True)
    global String phoneNum;
    @InvocableVariable(required=True)
    global Datetime due_date;
    @InvocableVariable(required=True)
    global String name;
    @InvocableVariable(required=True)
    global String task_id;
	@InvocableVariable(required=True)
    global String httpMethod;
    
}