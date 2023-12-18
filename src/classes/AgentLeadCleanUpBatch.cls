global class AgentLeadCleanUpBatch implements Database.Batchable<SObject>, Schedulable {

    final String query;

    global AgentLeadCleanUpBatch() {
        query = 'Select Id, Agent_Lead__c, Agent_Account__c, Broker_First_Name__c, Broker_Last_Name__c, Broker_License__c, ' +
            'Broker_Phone__c, Broker_Email__c, Brokers_Agency_Name__c, Broker_Agency_Other__c, Broker_License2__c ' +
            'from Lead where Agent_Lead__c = true';
    }

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Lead> scope) {

        List<Lead> leadsToProcess = new List<Lead>();
        Set<Id> leadIdsToProcess = new Set<Id>();
        Set<Id> agentIdsToProcess = new Set<Id>();

        for (Lead l : scope) {
            if (l.Agent_Account__c != null) {
                leadsToProcess.add(l);
                leadIdsToProcess.add(l.Id);
                agentIdsToProcess.add(l.Agent_Account__c);
            }
        }

        if (leadIdsToProcess.size() > 0) {
            List<Contact> agentContacts = [SELECT Id, AccountId FROM Contact WHERE AccountId IN :agentIdsToProcess];
            List<Interest_List__c> interestLists = [SELECT Id, Lead__c, Community_Site__c FROM Interest_List__c WHERE Lead__c IN :leadIdsToProcess];
            List<Task> tasks = [SELECT Id, WhoId FROM Task WHERE WhoId IN :leadIdsToProcess];
            List<Event> events = [SELECT Id, WhoId FROM Event WHERE WhoId IN :leadIdsToProcess];
            List<Site_Visit__c> visits = [SELECT Id, Lead__c FROM Site_Visit__c WHERE Lead__c IN :leadIdsToProcess];
            List<Note> notes = [SELECT Id, ParentId, Body, OwnerId, Title, IsPrivate FROM Note WHERE ParentId IN :leadIdsToProcess];
            List<Attachment> attachments = [SELECT Id, ParentId, Body, IsPrivate, Name, Description, OwnerId FROM Attachment WHERE ParentId IN :leadIdsToProcess];

            List<Interest_List__c> interestListsForUpdate = new List<Interest_List__c>();
            List<Task> tasksForUpdate = new List<Task>();
            List<Event> eventsForUpdate = new List<Event>();
            List<Site_Visit__c> visitsForUpdate = new List<Site_Visit__c>();
            List<Note> newNotes = new List<Note>();
            List<Attachment> newAttachments = new List<Attachment>();
            List<Account> agentAccountsForUpdate = new List<Account>();

            Map<Id, Set<Id>> agentCOIMap = new Map<Id, Set<Id>>();
            List<String> licenseNumbers = new List<String>();

            for (Interest_List__c interestList : [SELECT Id, Account__c, Community_Site__c FROM Interest_List__c WHERE Account__c IN :agentIdsToProcess]) {
                Set<Id> coiIds = new Set<Id>();
                if (agentCOIMap.get(interestList.Account__c) != null) {
                    coiIds = agentCOIMap.get(interestList.Account__c);
                }
                coiIds.add(interestList.Community_Site__c);
                agentCOIMap.put(interestList.Account__c, coiIds);
            }

            for (Lead lead : leadsToProcess) {
                if (leadDoesNotHaveLicenseNumberAndShouldBeSkipped(lead)) {
                    continue;
                }
                // Get Agent Contact Id
                Id contactId;
                for (Contact c : agentContacts) {
                    if (c.AccountId == lead.Agent_Account__c) {
                        contactId = c.Id;
                        break;
                    }
                }
                //Update COI Records
                Set<Id> agentCOIs = new Set<Id>();
                if (agentCOIMap.get(lead.Agent_Account__c) != null) {
                    agentCOIs = agentCOIMap.get(lead.Agent_Account__c);
                }

                for (Interest_List__c interestList : interestLists) {
                    if (interestList.Lead__c == lead.Id) {
                        if (agentCOIs != null && !agentCOIs.contains(interestList.Community_Site__c)) {
                            interestList.Account__c = lead.Agent_Account__c;
                            if (contactId != null) {
                                interestList.Contact__c = contactId;
                            }
                            interestList.Lead__c = null;
                            interestListsForUpdate.add(interestList);
                        }
                    }
                }

                //Update Task records
                for (Task t : tasks) {
                    if (t.WhoId == lead.Id) {
                        t.WhatId = lead.Agent_Account__c;
                        if (contactId != null) {
                            t.WhoId = contactId;
                        }
                        tasksForUpdate.add(t);
                    }
                }

                //Update Event records
                for (Event e : events) {
                    if (e.WhoId == lead.Id) {
                        e.WhatId = lead.Agent_Account__c;
                        if (contactId != null) {
                            e.WhoId = contactId;
                        }
                        eventsForUpdate.add(e);
                    }
                }

                //Update Site Visit records
                for (Site_Visit__c sv : visits) {
                    if (sv.Lead__c == lead.Id) {
                        sv.Account__c = lead.Agent_Account__c;
                        if (contactId != null) {
                            sv.Contact__c = contactId;
                        }
                        sv.Lead__c = null;
                        visitsForUpdate.add(sv);
                    }
                }

                //Copy Notes - notes cannot be reparented after insert
                for (Note n : notes) {
                    if (n.ParentId == lead.Id) {
                        Id parentId;
                        if (contactId != null) {
                            parentId = contactId;
                        }
                        else {
                            parentId = lead.Agent_Account__c;
                        }
                        Note newNote = new Note(
                            ParentId = parentId,
                            Body = n.Body,
                            IsPrivate = n.IsPrivate,
                            OwnerId = n.OwnerId,
                            Title = n.Title);
                        newNotes.add(newNote);
                    }
                }

                //Copy Attachments - attachments cannot be reparented after insert
                for (Attachment at : attachments) {
                    if (at.ParentId == lead.Id) {
                        Id parentId;
                        if (contactId != null) {
                            parentId = contactId;
                        }
                        else {
                            parentId = lead.Agent_Account__c;
                        }
                        Attachment newAtt = new Attachment(
                            ParentId = parentId,
                            Body = at.Body,
                            IsPrivate = at.IsPrivate,
                            OwnerId = at.OwnerId,
                            Name = at.Name,
                            Description = at.Description);
                        newAttachments.add(newAtt);
                    }
                }

                //skip leads with duplicate Licenses
                if (licenseNumbers.contains(lead.Broker_License__c.toLowerCase())) {
                    continue;
                }
                licenseNumbers.add(lead.Broker_License__c.toLowerCase());

                //sync Agent Account
                Account acct = new Account(Id = lead.Agent_Account__c);
                acct.Agent_First_Name__c = lead.Broker_First_Name__c;
                acct.Agent_Last_Name__c = lead.Broker_Last_Name__c;
                acct.Agent_License__c = lead.Broker_License__c;
                acct.Phone = lead.Broker_Phone__c;
                acct.Email__c = lead.Broker_Email__c;
                acct.Broker_s_Agency__c = lead.Brokers_Agency_Name__c;
                acct.Broker_Agency_Other__c = lead.Broker_Agency_Other__c;
                acct.Broker_License__c = lead.Broker_License2__c;
                agentAccountsForUpdate.add(acct);
            }

            //DML Statements
            if (interestListsForUpdate.size() > 0) {
                update interestListsForUpdate;
            }
            if (tasksForUpdate.size() > 0) {
                update tasksForUpdate;
            }
            if (eventsForUpdate.size() > 0) {
                update eventsForUpdate;
            }
            if (visitsForUpdate.size() > 0) {
                update visitsForUpdate;
            }
            if (newNotes.size() > 0) {
                insert newNotes;
            }
            if (newAttachments.size() > 0) {
                insert newAttachments;
            }
            if (agentAccountsForUpdate.size() > 0) {
                update agentAccountsForUpdate;
            }
            if (leadsToProcess.size() > 0) {
                delete leadsToProcess;
            }
        }
    }

    private static Boolean leadDoesNotHaveLicenseNumberAndShouldBeSkipped(Lead lead) {
        return String.isBlank(lead.Broker_License__c);
    }


    global void finish(Database.BatchableContext BC) {

    }

    global void execute(SchedulableContext SC) {
        Database.executeBatch(new AgentLeadCleanUpBatch());
    }

}
