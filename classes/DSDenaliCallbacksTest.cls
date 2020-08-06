/***************************************************

****************************************************/
@isTest
global class DSDenaliCallbacksTest {
    
	global class MockHttpPutResponseGenerator implements HttpCalloutMock {
    // Implement this interface method
    	global HTTPResponse respond(HTTPRequest req) {
        // Optionally, only send a mock response for a specific endpoint
        // and method.
        System.assertEquals('http://api.salesforce.com/foo/bar' + '&number=' + '&object_name=', req.getEndpoint());
        System.assertEquals('PUT', req.getMethod());
        
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"foo":"bar"}');
        res.setStatusCode(200);
        return res;
    }
}
    @isTest
    public static void sendContactGlobal()
    {
        List<DSDenaliCallbacksPBVariables> listVars = new List<DSDenaliCallbacksPBVariables>(); 
        
              
        DSDenaliCallbacksPBVariables newVars1 = new DSDenaliCallbacksPBVariables(); 
        DSDenaliCallbacksPBVariables newVars2 = new DSDenaliCallbacksPBVariables(); 
        DSDenaliCallbacksPBVariables newVars3 = new DSDenaliCallbacksPBVariables();
        
        Account a = new Account();
        a.Name = 'DialSource Incorporated';
        insert a;
        
        
        
        Contact c = new Contact();
        c.Phone = '1 (737) 204-0210';
        c.FirstName = 'John'; 
        c.LastName  = 'Matrix';
        c.AccountId = a.Id;
        insert c;
        
        Task t = new Task();
        t.Subject = 'Cool subject line';
        t.OwnerId = UserInfo.getUserId();
        t.Status = 'Not Started';
        t.Priority = 'Normal';
        t.WhoId = c.Id;
        
        insert t;
        
        newVars1.object_id = c.Id;
        newVars1.phoneNum = c.Phone;
        newVars1.name = c.Name;
        newVars1.due_date = System.now(); 
        newVars1.task_id = t.Id;
        
        //t.Set_Denali_Callback__c = true;
		t.Type = 'Denali Callback';
        t.ReminderDateTime = (system.now() + 1);
        t.isReminderSet = true;
        update t;
        
        //Add the records to the list
        listVars.add(newVars1); 
        
        Test.startTest(); 
        MockHttpPutResponseGenerator mock = new MockHttpPutResponseGenerator();
        DSDenaliCallbacksInvocablePB.setup(listVars);
        Test.stopTest(); 
        
        //Check how many records we queued
        System.assertEquals(listVars.size(), listVars.size(), '1 Records was not queued');  
    }
    
    @isTest
    public static void sendLeadGlobal()
    {
        List<DSDenaliCallbacksPBVariables> listVars = new List<DSDenaliCallbacksPBVariables>(); 
        
        DSDenaliCallbacksPBVariables newVars1 = new DSDenaliCallbacksPBVariables(); 
        DSDenaliCallbacksPBVariables newVars2 = new DSDenaliCallbacksPBVariables(); 
        DSDenaliCallbacksPBVariables newVars3 = new DSDenaliCallbacksPBVariables();
        
        Lead l = new Lead();
        l.LastName = 'Smith';
        l.Phone = '1 (737) 204-0210';
        l.FirstName = 'Dirk'; 
        l.LastName  = 'Diggler';
        l.Company = 'Boogie Nights';
        insert l;
        
        Task t = new Task();
        t.Subject = 'Cool subject line';
        t.OwnerId = UserInfo.getUserId();
        t.Status = 'Not Started';
        t.Priority = 'Normal';
        t.WhoId = l.Id;
        t.Type = 'Denali Callback';
        t.ReminderDateTime = (system.now() + 1);
        t.isReminderSet = true;
        insert t;

        Task tFail = new Task();
        tFail.Subject = 'Cool subject line';
        tFail.OwnerId = UserInfo.getUserId();
        tFail.Status = 'Not Started';
        tFail.Priority = 'Normal';
        tFail.WhoId = l.Id;
        tFail.Type = 'Denali Callback';
        tFail.ReminderDateTime = (system.now() - 1);
        tFail.isReminderSet = true;
        
        try {
        	insert tFail;
        }
        catch (Exception e){
            Boolean expectedExceptionThrown =  e.getMessage().contains('Please set a future reminder date time to create a callback task.');
            //? true : false;
            System.AssertEquals(expectedExceptionThrown, true);
        }
        
        Task tFail2 = new Task();
        tFail2.Subject = 'Cool subject line';
        tFail2.OwnerId = UserInfo.getUserId();
        tFail2.Status = 'Not Started';
        tFail2.Priority = 'Normal';
        tFail2.WhoId = l.Id;
        tFail2.Type = 'Denali Callback';
        tFail2.ReminderDateTime = (system.now() - 1);
        tFail2.isReminderSet = false;
        
        try {
        	insert tFail2;
        }
        catch (Exception e){
            Boolean expectedExceptionThrown =  e.getMessage().contains('Cannot set callback task');
            //? true : false;
            System.AssertEquals(expectedExceptionThrown, true);
        }

        newVars1.object_id = l.Id;
        newVars1.phoneNum = l.Phone;
        newVars1.name = l.Name;
        newVars1.due_date = System.now(); 
        newVars1.task_id = t.Id;
        
        //t.Set_Denali_Callback__c = true;
		/*t.Type = 'Denali Callback';
        t.ReminderDateTime = (system.now() + 1);
        t.isReminderSet = true;
        update t;*/
        
        //Add the records to the list
        listVars.add(newVars1); 
        
        Test.startTest();
        DSDenaliCallbacksInvocablePB.setup(listVars);
        Test.stopTest(); 

        
        //Check how many records we queued
        System.assertEquals(listVars.size(), listVars.size(), '1 Records was not queued');

        t.ReminderDateTime = null;
        try {
        	update t;
        }
        catch (Exception e){
            Boolean expectedExceptionThrown =  e.getMessage().contains('Cannot set callback task');
            //? true : false;
            System.AssertEquals(expectedExceptionThrown, true);
        }

        t.ReminderDateTime = System.now() - 1;
        try {
        	update t;
        }
        catch (Exception e){
            Boolean expectedExceptionThrown =  e.getMessage().contains('Reminder time for Callback is');
            //? true : false;
            System.AssertEquals(expectedExceptionThrown, false);
        }
    }
    
    @isTest
    public static void sendAccountGlobal()
    {
        List<DSDenaliCallbacksPBVariables> listVars = new List<DSDenaliCallbacksPBVariables>(); 
        
              
        DSDenaliCallbacksPBVariables newVars1 = new DSDenaliCallbacksPBVariables(); 
       
        
        Account a = new Account();
        a.Name = 'DialSource Incorporated';
        a.Phone = '5556234512';
        insert a;

        
        Task t = new Task();
        t.Subject = 'Cool subject line';
        t.OwnerId = UserInfo.getUserId();
        t.Status = 'Not Started';
        t.Priority = 'Normal';
        t.WhatId = a.Id;
        
        insert t;
        
        newVars1.object_id = a.Id;
        newVars1.phoneNum = a.Phone;
        newVars1.name = a.Name;
        newVars1.due_date = System.now(); 
        newVars1.task_id = t.Id;
        
        //t.Set_Denali_Callback__c = true;
		t.Type = 'Denali Callback';
        t.ReminderDateTime = (system.now() + 1);
        t.isReminderSet = true;
        update t;
        
        //Add the records to the list
        listVars.add(newVars1); 
        
        Test.startTest(); 
        DSDenaliCallbacksInvocablePB.setup(listVars);
        
        Test.stopTest(); 
        
        //Check how many records we queued
        System.assertEquals(listVars.size(), listVars.size(), '1 Records was not queued');
        
        
    }
    
    @isTest
    public static void sendCaseGlobal()
    {
        List<DSDenaliCallbacksPBVariables> listVars = new List<DSDenaliCallbacksPBVariables>(); 
        
              
        DSDenaliCallbacksPBVariables newVars1 = new DSDenaliCallbacksPBVariables(); 
       
        
        Account a = new Account();
        a.Name = 'DialSource Incorporated';
        a.Phone = '5556234512';
        insert a;
        
        Contact con = new Contact(
                lastName='test name', 
                AccountId=a.Id, 
                Phone = '8315881046');
        insert con;

        Case c = new Case();
        c.Origin = 'Phone';
        c.ContactId = con.Id;
        C.Status = 'New';
        c.Subject = 'Oh no something broke';
        c.AccountId = a.Id;
        //c.ContactPhone = '1231231234';
        insert c;

        
        Task t = new Task();
        t.Subject = 'Cool subject line';
        t.OwnerId = UserInfo.getUserId();
        t.Status = 'Not Started';
        t.Priority = 'Normal';
        t.WhatId = c.Id;
        
        insert t;
        
        newVars1.object_id = c.Id;
        newVars1.phoneNum = '1231231234';
        newVars1.name = c.Subject;
        newVars1.due_date = System.now() + (2/1440); 
        newVars1.task_id = t.Id;
        
        //t.Set_Denali_Callback__c = true;
		t.Type = 'Denali Callback';
        t.ReminderDateTime = (system.now() + 1);
        t.isReminderSet = true;
        update t;
        
        //Add the records to the list
        listVars.add(newVars1); 
        
        Test.startTest(); 
        DSDenaliCallbacksInvocablePB.setup(listVars);
        Test.stopTest(); 
        
        //Check how many records we queued
        System.assertEquals(listVars.size(), listVars.size(), '1 Records was not queued');


    }


    @isTest
    public static void queueableLimit()
    {
        List<DSDenaliCallbacksPBVariables> listVars = new List<DSDenaliCallbacksPBVariables>(); 
        
        DSDenaliCallbacksPBVariables newVars1 = new DSDenaliCallbacksPBVariables(); 
        DSDenaliCallbacksPBVariables newVars2 = new DSDenaliCallbacksPBVariables(); 
        DSDenaliCallbacksPBVariables newVars3 = new DSDenaliCallbacksPBVariables();
        
        Task t = new Task();
        t.Subject = 'Cool subject line';
        t.OwnerId = UserInfo.getUserId();
        t.Status = 'Not Started';
        t.Priority = 'Normal';
        t.Type = 'Denali Callback';
        t.ReminderDateTime = (system.now() + 1);
        t.isReminderSet = true;
        insert t;
        
        newVars1.object_id = '00Q50000018Z3wK';
        newVars1.phoneNum = '1(737) 204-0210';
        newVars1.name = 'Charles';
        newVars1.due_date = System.now(); 
        newVars1.task_id = t.Id;
        
        newVars2.object_id = '00Q50000018Z3wK';
        newVars2.phoneNum = '1(737) 204-0210';
        newVars2.name = 'Star';
        newVars2.due_date = System.now(); 
        newVars2.task_id = t.Id;
        
        newVars3.object_id = '00Q50000018Z3wK';
        newVars3.phoneNum = '1(737) 204-0210';
        newVars3.name = 'Scott';
        newVars3.due_date = System.now(); 
        newVars3.task_id = t.Id;
        
        
        //Add the records to the list
        listVars.add(newVars1); 
        listVars.add(newVars2); 
        listVars.add(newVars3);
        
        //Go past the queueable limit
        for (Integer i = 0; i < 51; i++)
            DSDenaliCallbacksInvocablePB.setup(listVars);
        
        //Check how many records we queued
        System.assertEquals(listVars.size(), listVars.size(), '3 Records were not queued'); 
    }
}