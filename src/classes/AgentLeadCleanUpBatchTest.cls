@isTest
private class AgentLeadCleanUpBatchTest {
    Public Static Map<String,String> testMetaDataMap;
    @isTest
    private static void testExecute() {
        //<Modification>- Sushama on June 15, 2020 as per SPDN-9, to avoid exception because of new validation rule.
        //List<Lead> leads = TestDataFactory.createLeadsProcessed(1);
        
        //Insert Division Settings
        Division_setting__c division= Test_Methods_Utils.createDivSetting('Sliding Percent');
        
        //Insert Community Site1
        Community_Site__c community= Test_Methods_Utils.setUpCommunitySite('Pardee Homes', division.ID, true);
        
        //Insert Community Site2
        Community_Site__c community1= Test_Methods_Utils.setUpCommunitySite('Test', division.ID, true);
        
        //Insert Agent Account    
        Account agentAccount= Test_Methods_Utils.setUpAccount('Agent Account', 'Agent', true);               
        
        //Create COI under Agent Account
        Interest_List__c il= new Interest_List__c(Community_Site__c = community.Id, Account__c = agentAccount.Id);
        INSERT il;   

        Lead l = new Lead(
            FirstName = 'Test',
            LastName = 'Lead1',
            Company = 'TestCo',
            Email = 'test@gmail.com',
            Phone = '3031111111',
            Agent_Account__c = agentAccount.ID,
            Agent_Lead__c = true,
            Broker_First_Name__c ='test',
            Broker_Last_Name__c = 'test',
            Broker_License__c = 'test9845222222',
            Broker_Email__c = 'test@agenttest.com',
            Broker_Phone__c = '1234567890',
            MobilePhone = '30302222222');
        insert l;
        
        //Create Event under Lead
        Event e1 = new Event();
            e1.ActivityDateTime= system.now();
            e1.Subject = 'Other';
            e1.Task_Type__c = 'Other';
            e1.Appointment_Kept__c = 'Yes'; 
            e1.Location= 'WHISPERING PINES';
            e1.WhoId = l.Id;
            e1.DurationInMinutes = 15;
            insert e1;  
        
        //Create COI under Lead 
        Interest_List__c ilLead= new Interest_List__c(Community_Site__c = community1.Id, Lead__c = l.Id);
        INSERT ilLead;
        
        //Insert Site visit under Lead
        Site_Visit__c sv = new Site_Visit__c();
        sv.Agent_Account__c = agentAccount.ID;
        sv.Lead__c = l.ID;  
        sv.Community_Site__c = community.Id;
        sv.Arrival_Time__c  = datetime.newInstance(2017, 12, 25,12,30,0); 
        INSERT sv;                  
        
        //Create Note under Lead
        Note newNote = new Note(
                        ParentId = l.ID,
                        Body = 'Test',
                        IsPrivate = false,
                        Title = 'test');                           
        INSERT newNote;                  
       
        //Create Attachment under Lead
        Blob bodyBlob=Blob.valueOf('Unit Test Attachment Body');
        Attachment newAtt = new Attachment(
                        ParentId = l.ID,                            
                        Body = bodyBlob,
                        IsPrivate = false,
                        Name = 'Testtest',
                        Description = 'Test');
        INSERT newAtt;
         
        //Create Task under Lead 
        Task t1 = new Task();
        t1.ActivityDate = system.today();
        t1.Subject = 'Other';
        t1.Task_Type__c = 'Other';
        t1.Appointment_Kept__c = 'Yes'; 
        t1.Division__c = 'TPH - Colorado';
        t1.Community_Site_Picklist__c = 'WHISPERING PINES';
        t1.WhoId = l.Id;
        insert t1;  

        //</Modification>- Sushama 
        
        Test.startTest();
            AgentLeadCleanUpBatch obj = new AgentLeadCleanUpBatch();
            DataBase.executeBatch(obj);
        Test.stopTest();
    }
}