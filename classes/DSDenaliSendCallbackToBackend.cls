/***************************************************

Brief Description: DialSource Denali Callbacks
****************************************************/
global class DSDenaliSendCallbackToBackend implements System.Queueable, Database.AllowsCallouts {

    private List<DSDenaliSendCallbackToBackend.DSCallBackTask> dscbl;
    private String urlParamList; 
    //private String key; 
    private String aid; 
	global String userId;
    global String objectId;
    global String phoneNumber;
    global Long dueDate;
    global String oName;
    global String taskId;
    
    //Record data
    public class DSCallBackTask 
    {
        String uid;
        String object_id;
        String phone_number;
        //String due_date; 
        Long due_date;
        String name;
        String task_id;
 		String httpMethod;

        
        public DSCallBackTask(String uid, String object_id, String phone_number, Datetime due_date, String name, String task_id, String httpMethod)
        {
            this.uid = uid;
            this.object_id = object_id;
            this.phone_number = phone_number;
            //this.due_date = due_date.formatGMT('yyyy-MM-dd HH:mm:ss'); 
            this.due_date = due_date.getTime(); 
            this.name = name;
            this.task_id = task_id;
            this.httpMethod = httpMethod;
        }
    }

    
    
    //Collect the records to send to Callback
    public DSDenaliSendCallbackToBackend(List<DSDenaliCallbacksPBVariables> callbackVars)
    {
        dscbl = new List<DSDenaliSendCallbackToBackend.DSCallBackTask>();
        aid = UserInfo.getOrganizationId();
        system.debug('AID: '+aid);

        for (DSDenaliCallbacksPBVariables var : callbackVars)
        {
            DSCallBackTask newCallBack;
            
			/*userId = var.uid; 
            objectId = var.object_id;
            phoneNumber = CorrectPhoneNumber(var.phoneNum);
            dueDate = var.due_date.getTime();
            oName = var.name;
            taskId = var.task_id;*/
            
            //Skip records with no phone number
            if (var.phoneNum != NULL)
                newCallBack = new DSCallBackTask(var.uid, 
                                                 var.object_id, 
                                                 CorrectPhoneNumber(var.phoneNum), 
                                                 var.due_date, 
                                                 var.name, 
                                                 var.task_id,
                                                 var.httpMethod);
            else 
               continue; 

            dscbl.add(newCallBack); 
        }

        System.debug(dscbl.size()+' DSCBL Requests --- List: ' + dscbl);
    }

    //Collect the records to send to Callback
    public DSDenaliSendCallbackToBackend(List<DSCallBackTask> callbackVars)
    {
        dscbl = callbackVars; aid = UserInfo.getOrganizationId();
        system.debug('AID: '+aid);

        System.debug('Requeueing '+dscbl.size()+' DSCBL Requests --- List: ' + dscbl);
    }
    
    public void execute(QueueableContext context)
    {
        system.debug('In Execute --- '+dscbl.size()+' Callouts to Send');

        //Get the current endpoint from the DialSource Backend
        String dsEndpoint;

        //Create Http objects for GET
        Http http = new Http();
        HttpRequest request = new HttpRequest();

        //Populate Request
        request.setEndpoint('https://deployments.dialsource.com/accounts/' + UserInfo.getOrganizationId() + '/users/' +
                            UserInfo.getUserId() + '/deployment');
        request.setMethod('GET');
		HttpResponse response;
        
        //Send the Request
        if(!Test.isRunningTest()){
        	response = http.send(request);
        }
        
        // If the request is successful, parse the JSON response.
        
        if (response != null && response.getStatusCode() == 200) 
        {
            // Deserialize the JSON string into collections of primitive data types.
            Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
            
            //Extract 'services' object
            Map<String, object> services = (Map<String, Object>) results.get('services');
            
            //Extract PUT url from services
            String putUrl = String.valueOf(services.get('openapi'));
            dsEndpoint = putUrl;
                
                
                System.debug('Successful Response from initial GET Request. URL for POST --- '+results);
        }
           
        //Otherwise, set dsEndpoint to defult
        else {
            dsEndpoint = 'https://in.dialsource.com';
            System.debug('Unsuccessful Response from initial GET Request. URL for POST --- '+dsEndpoint);
        }

        //Send up to first 99 Requests
        Integer loopCount = 0;
        //for(Integer i=0; i < loopCount; i++)
        while(dscbl.size() > 0)
        {
            //If limit is reached, break and re-queue
            if(Limits.getCallouts() == Limits.getLimitCallouts()){
                system.debug('BREAKING LOOP - CALLOUT LIMIT REACHED --- '+Limits.getCallouts()+' Callouts Sent || '+dscbl.size()+' Requests remaining.');
                break;
            }
            
            //Get Request object and remove Request from list to process
            DSCallBackTask cb = dscbl.remove(0);
            loopCount++;

            //Create Http objects for POST
            String httpBody = '';
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            String URL = dsEndpoint;
		
            //Populate Request
            
            req.setMethod(cb.httpMethod);
            req.setHeader('Connection', 'keep-alive');
            req.setTimeout(120000);
        
            //convert timestamp to unix 10 character string
            String timestamp = cb.due_date.format().left(13);
            timestamp = timestamp.replaceAll(',', '');
            //System.debug('due date = ' + timestamp);
        
            //set the URL with all the params for the request
            if(cb.httpMethod == 'PUT'){
            URL = URL + '/callback' + '?aid=' + aid + '&uid=' + cb.uid + '&object_id=' + cb.object_Id + '&due_date=' + timestamp + '&name=' + cb.name + '&number=' + cb.phone_number + 
                '&task_id=' + cb.task_id;
			}
            
            //Format URL and set it as the endpoint for the PUT Request
            URL = URL.replace(' ', '%20');
            req.setEndpoint(URL);
            //System.debug('URL = ' + URL );
            system.debug('Iteration #'+loopCount+': Req= ' + req);
            
            //Send the request
            try{
                if (!Test.isRunningTest())
                {
                    HttpResponse res = h.send(req);
                    System.debug('response ' + 
                                 res.getBody() + ' ' + 
                                 res.getStatus());
                }
            }
            
            catch (Exception ex){
                System.debug('Callbacks error: ' + ex);
            }
        }

        system.debug(dscbl.size()+' Requests remaining to send.');

        //If any requests weren't sent, requeue this job with fresh limits and the remaining Requests
        if(!dscbl.isEmpty())
        {
            system.enqueueJob(new DSDenaliSendCallbackToBackend(dscbl));
        }
    }
    
    @Future(callout=true)    
    global static void dsDeleteCallback(Id aid, Id uid, Id object_id, String phone_number, 
                                      Datetime due_date, String timestamp, String name, Id task_id)
    {
        dsDeleteCallbackSync(aid, uid, object_id, phone_number, 
                                       due_date, timestamp, name, task_id);
    }
    global static void dsDeleteCallbackSync(Id aid, Id uid, Id object_id, String phone_number, 
                                      Datetime due_date, String timestamp, String name, Id task_id)
    {
        String httpBody = '';
        Http h = new Http();
        HttpRequest req = new HttpRequest();
        String URL;
        
        //format phone number into string with no special characters
        phone_number = phone_number.replaceAll('[^0-9+]', '');
        //Remove possible leading 1.
        if(phone_number.substring(0, 1) == '1')
        {
            phone_number = phone_number.substring(1, phone_number.length());
        }

        
		        
        //get the URL from the deployments endpoint
        String getUrl;
        
        
        
		Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://deployments.dialsource.com/accounts/' +
                                UserInfo.getOrganizationId() + '/users/' +
                                UserInfo.getUserId() + '/deployment');
            request.setMethod('GET');
        	HttpResponse response;
        	
        if(!Test.isRunningTest()) {
			 response = http.send(request);
			}
        // If the request is successful, parse the JSON response.
            if (response != null && response.getStatusCode() == 200) {
                
                // Deserialize the JSON string into collections of primitive data types.
                Map<String, Object> results = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                
                
                Map<String, object> services = (Map<String, Object>) results.get('services');
                
                String postUrl = String.valueOf(services.get('openapi'));
                System.debug('services? ' + postUrl); 
                URL = postUrl;
                
                
                System.debug(results);
            } else {
                URL = '';
            }
        
        
        req.setMethod('DELETE');
        req.setHeader('Connection', 'keep-alive');
        req.setTimeout(120000);
        
        
        //handle due date
        
        //due_date = due_date.formatGmt('yyyy-MM-dd HH:mm:ss');
        
        Long dtLong = due_date.getTime();
        String dtLongString = dtLong.format();
        timestamp = dtLongString.left(13).replaceAll(',', '');
        System.debug('due date = ' + timestamp);
		        
        //set the URL with all the params for the request
        URL = URL + '/callback' + '?aid=' + aid + '&uid=' + uid +  '&object_id=' + object_id + '&due_date=' + timestamp +  '&name=' + name + '&number=' + phone_number + 
            '&task_id=' + task_id;

        
        URL = URL.replace(' ', '%20');
        req.setEndpoint(URL);
        system.debug(URL);
        system.debug('Req= ' + req);
        
        //Send the request
        try{
            if (!Test.isRunningTest())
            {
                HttpResponse res = h.send(req);
                System.debug('URL = ' + URL );
                System.debug('response ' + res.getBody() + ' ' + res.getStatus());
            }
        }
        
        catch (Exception ex){
            System.debug('Callbacks error: ' + ex);
        }
    }

    global String CorrectPhoneNumber(String phoneNumber)
    {
        //Regex removes non-numeric characters.
        phoneNumber = phoneNumber.replaceAll('[^0-9+]', '');
        //Remove possible leading 1.
        if(phoneNumber.substring(0, 1) == '1')
        {
            phoneNumber = phoneNumber.substring(1, phoneNumber.length());
        }
        
        //System.debug(phoneNumber);
        
        return phoneNumber;
    }
}