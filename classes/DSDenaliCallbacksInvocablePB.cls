/***************************************************
Anthony Kelly, Developer, June 2020



Brief Description: DS Denali Class. Sends callbacks w/
parameters to queue.
****************************************************/
global class DSDenaliCallbacksInvocablePB 
{
    @InvocableMethod(label='DS Denali Create Callbacks' description='Set Custom Denali Callbacks on the Task object')
    global static void setup(List <DSDenaliCallbacksPBVariables> newRecords)
    {
        try 
        {
            DSDenaliSendCallbackToBackend clbk = new DSDenaliSendCallbackToBackend(newRecords);
            
            System.debug(newRecords + ' new records');
            System.debug('clbk : ' + clbk);
            
            if (Limits.getQueueableJobs() < Limits.getLimitQueueableJobs() && !test.isRunningTest())
                ID jobID = System.enqueueJob(clbk);
            else 
                throw new queueableLimitException('Too many queueable jobs added to the queue: ' + (Limits.getQueueableJobs() + 1));
        }
        
        catch (queueableLimitException ex)
        {
            System.debug('Callbacks error: ' + ex);
            //DSDenaliErrorEmail.sendError('DSDenaliCallbacksInvocablePB', ex);
        }
    }

    public class queueableLimitException extends Exception {}
}