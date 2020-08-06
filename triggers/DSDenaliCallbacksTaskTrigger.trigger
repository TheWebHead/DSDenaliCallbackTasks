/****
 * 6/15/2020 Anthony Kelly, Developer
 * Trigger to create callbacks on any old task the agent would like.
 * 'Denali Callback' needs to be added to the task "Type" field by an admin.
 * When Task is 'Denali Callback' type and has a reminder date/time non null
 * and set at least one minute in the future, it will create a callback.
 ****/

trigger DSDenaliCallbacksTaskTrigger on Task(after insert, after update, after delete) {

    List < Task > tasksToUpdate = new List < Task > ();

    //set to true if meets criteria for
    //sending to callback
    Boolean runCheck = false;
    
    
    /*
    //constructor variables
    String objType;
    Id accId = UserInfo.getOrganizationId();
    Id userId;
    Id objId;
    String phoneNum;
    Datetime dueDate;
    String timestamp;
    String objName;
    Id tId;
    */

    //Sets for querying
    Map<Id, Task> leadIds = new Map<Id, Task>();
    Map<Id, Task> contactIds = new Map<Id, Task>();
    Map<Id, Task> acctIds = new Map<Id, Task>();
    Map<Id, Task> caseIds = new Map<Id, Task>();

    //List of Requests to submit
    List<DSDenaliCallbacksPBVariables> reqs = new List<DSDenaliCallbacksPBVariables>();
    List<Task> triggerContext = new List<Task>();

    //set Trigger.new or Trigger.old based on context
    if(Trigger.isUpdate || Trigger.isInsert){
        triggerContext = trigger.new;
    }
    else if(Trigger.isDelete){
        triggerContext = trigger.old;
    }

    //Iterate through incoming Tasks - check conditions to trigger a request to callbacks endpoint
    //runCheck is set to true if conditions are met
    for (Task t: triggerContext) 
    {   
        //Update Conditions
        if (Trigger.isUpdate)
        {
            //Get old Task
            Task oldTask = trigger.oldMap.get(t.Id);
            system.debug('Old Task --- '+oldTask);

            //Identify Denali Callback Tasks
            if(
                //Type is changed to Denali Callback
                (t.Type == 'Denali Callback' && oldTask.Type != 'Denali Callback')
                ||
                //Reminder Datetime is changed on existing Callback
                ((t.Type == 'Denali Callback' || t.Subject.contains('Denali Callback Task')) && 
                (t.ReminderDateTime <> oldTask.ReminderDateTime))
                ){
                    //Validate Task data

                    //Callback is missing required values
                    if(t.ReminderDateTime == null || !t.isReminderSet)
                    {
                        t.addError('Cannot set callback task: Reminder Datetime is blank or Task is Completed');
                        runCheck = false;
                    }
                    //Callback is set in the past
                    else if(t.isReminderSet && t.ReminderDateTime < System.Now())
                    {
+                        t.ReminderDateTime = System.Now() + 1;
+                        runCheck = true;
                    }
                    
                    //Callback is correctly set
                    else if(t.ReminderDateTime != null && t.IsReminderSet == true)
                    {
                        runCheck = true;
                    }
            }
            
        }
        
        //Insert Conditions for Denali Callback Tasks
        if(Trigger.isInsert && t.Type == 'Denali Callback')
        {
            //Validate Task data
            
            //Callback is missing required values
            if(t.ReminderDateTime == null || !t.isReminderSet)
            {
                t.addError('Cannot set callback task: Reminder Datetime is blank or Task is Completed');
                runCheck = false;
            }
            //Callback is set in the past
            else if(t.IsReminderSet && t.ReminderDateTime < System.now())
            {
                t.addError('Please set a future reminder date time to create a callback task.');
                runCheck = false;
            }
            
            //Callback is correctly set
            else if(t.ReminderDateTime != null && t.IsReminderSet == true)
            {
                runCheck = true;
            }

        }
        
        //if deleting callback task, proceed
        if(Trigger.isDelete && t.Type == 'Denali Callback') {
            runCheck = true;
            System.debug('is delete');
        }

        //If the Task meets the coniditions above, extract the related object ID
        if(runCheck)
        {
            //Determine related object type
            String objectAPIName;

            //logic for whoId -- Lead or Contact
            if (t.WhoId != null){
                objectAPIName = t.WhoId.getSobjectType().getDescribe().getName();
            }
            //logic for whatId -- Accounts or Cases
            else if(t.WhatId != null){
                objectAPIName = t.WhatId.getSobjectType().getDescribe().getName();
            }

            //Populate collections for querying
            if(objectAPIName == 'Lead') leadIds.put(t.WhoId, t);
            if(objectAPIName == 'Contact') contactIds.put(t.WhoId, t);
            if(objectAPIName == 'Account') acctIds.put(t.WhatId, t);
            if(objectAPIName == 'Case') caseIds.put(t.WhatId, t);
        }
    }

    //Get Related Records and populate Requests
    //Leads
    if(!leadIds.isEmpty())
    {
        //Get Leads related to Task
        List<Lead> leads = [select id, name, LastModifiedById, phone from Lead where Id IN: leadIds.keySet()];
        system.debug(leads.size()+' Related Leads --- '+leads);
        
        //Create and populate Request
        for(Lead rec: leads)
        {
            //Get original Task
            Task t = leadIds.get(rec.Id);
            
            //Create Request
            DSDenaliCallbacksPBVariables pbv = new DSDenaliCallbacksPBVariables();

            if(Trigger.isUpdate || Trigger.isInsert) {
            //Map values
            pbv.due_date= t.ReminderDateTime;
            pbv.name= rec.Name;
            pbv.object_id=rec.Id;
            pbv.phoneNum=rec.Phone;
            pbv.task_id=t.Id;
            pbv.uid = rec.LastModifiedById;
            pbv.httpMethod='PUT';
            reqs.add(pbv);
            
            }
            else if (Trigger.isDelete){
                DSDenaliSendCallbackToBackend.dsDeleteCallback(UserInfo.getOrganizationId(), t.OwnerId, rec.Id, rec.Phone, t.ReminderDateTime, t.ReminderDateTime.format().left(13).replaceAll(',', ''), rec.Name, t.Id);
                
            }
        }
    }
    //Contacts
    if(!contactIds.isEmpty())
    {
        //Get Contacts related to Task
        List<Contact> contacts = [select id, name, LastModifiedById, phone from Contact where Id IN: contactIds.keySet()];
        system.debug(contactIds.size()+' Related Contacts --- '+contacts);
        
        //Create and populate Request
        for(Contact rec: contacts)
        {
            //Get original Task
            Task t = contactIds.get(rec.Id);
            
            //Create Request
            DSDenaliCallbacksPBVariables pbv = new DSDenaliCallbacksPBVariables();

            if(Trigger.isUpdate || Trigger.isInsert) {
            //Map values
            pbv.due_date= t.ReminderDateTime;
            pbv.name= rec.Name;
            pbv.object_id=rec.Id;
            pbv.phoneNum=rec.Phone;
            pbv.task_id=t.Id;
            pbv.uid = rec.LastModifiedById;
            pbv.httpMethod='PUT';
            reqs.add(pbv);
            
            }
            else if (Trigger.isDelete){
                DSDenaliSendCallbackToBackend.dsDeleteCallback(UserInfo.getOrganizationId(), t.OwnerId, rec.Id, rec.Phone, t.ReminderDateTime, t.ReminderDateTime.format().left(13).replaceAll(',', ''), rec.Name, t.Id);
                
            }
        }
    }
    //Accounts
    if(!acctIds.isEmpty())
    {
        //Get Accounts related to Task
        List<Account> accts = [select id, name, LastModifiedById, phone from Account where Id IN: acctIds.keySet()];
        system.debug(accts.size()+' Related Accounts --- '+accts);
        
        //Create and populate Request
        for(Account rec: accts)
        {
            //Get original Task
            Task t = acctIds.get(rec.Id);
            
            //Create Request
            DSDenaliCallbacksPBVariables pbv = new DSDenaliCallbacksPBVariables();

            if(Trigger.isUpdate || Trigger.isInsert) {
            //Map values
            pbv.due_date= t.ReminderDateTime;
            pbv.name= rec.Name;
            pbv.object_id=rec.Id;
            pbv.phoneNum=rec.Phone;
            pbv.task_id=t.Id;
            pbv.uid = rec.LastModifiedById;
            pbv.httpMethod='PUT';
            reqs.add(pbv);
            
            }
            else if (Trigger.isDelete){
                DSDenaliSendCallbackToBackend.dsDeleteCallback(UserInfo.getOrganizationId(), t.OwnerId, rec.Id, rec.Phone, t.ReminderDateTime, t.ReminderDateTime.format().left(13).replaceAll(',', ''), rec.Name, t.Id);
                
            }
        }
    }
    //Cases
    if(!caseIds.isEmpty())
    {
        //Get Cases related to Task
        List<Case> cases = [select id, Subject, LastModifiedById, ContactPhone from Case where Id IN: caseIds.keySet()];
        system.debug(cases.size()+' Related Cases --- '+cases);
        
        //Create and populate Request
        for(Case rec: cases)
        {
            //Get original Task
            Task t = caseIds.get(rec.Id);
            
            //Create Request
            DSDenaliCallbacksPBVariables pbv = new DSDenaliCallbacksPBVariables();

            if(Trigger.isUpdate || Trigger.isInsert) {
            //Map values
            pbv.due_date= t.ReminderDateTime;
            pbv.name= rec.Subject;
            pbv.object_id=rec.Id;
            pbv.phoneNum=rec.ContactPhone;
            pbv.task_id=t.Id;
            pbv.uid = rec.LastModifiedById;
            pbv.httpMethod='PUT';
            reqs.add(pbv);
            
            }
            else if (Trigger.isDelete){
                DSDenaliSendCallbackToBackend.dsDeleteCallback(UserInfo.getOrganizationId(), t.OwnerId, rec.Id, rec.ContactPhone, t.ReminderDateTime, t.ReminderDateTime.format().left(13).replaceAll(',', ''), rec.Subject, t.Id);
                
            }
        }
    }

    //Send Reqs to Queueable class to perform callout
    system.debug(reqs.size()+' Requests for Callbacks.');
    if(!reqs.isEmpty())
    {
        DSDenaliCallbacksInvocablePB.setup(reqs);
    }


       
}