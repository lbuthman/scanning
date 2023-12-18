//=================================================================================================
// Company: TRI Pointe Group
//  Author: Matt Starr (EnablePath)
// Created: 11/14/2016     
// Comment: Batch class to remove Agent leads that have been processed. RFC90001
//=================================================================================================
//          Date            Purpose
// 11/14/2016               Matt Starr (EnablePath) Created
//=================================================================================================
global class AgentLeadCleanUpBatch implements Database.Batchable<sObject>, Schedulable {
	
	String query;
	
	global AgentLeadCleanUpBatch() {
		query = 'Select Id, Agent_Lead__c, Agent_Account__c, Broker_First_Name__c, Broker_Last_Name__c, Broker_License__c, '+
				'Broker_Phone__c, Broker_Email__c, Brokers_Agency_Name__c, Broker_Agency_Other__c, Broker_License2__c '+
				'from Lead where Agent_Lead__c = true';
	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
		return Database.getQueryLocator(query);
	}

	global void execute(Database.BatchableContext BC, List<Lead> scope) {

		List<Lead> leadsToProcess = new List<Lead>();
		Set<Id> leadIdsToProcess = new Set<Id>();
		Set<Id> agentIdsToProcess = new Set<Id>();

		for(Lead l : scope){
			if(l.Agent_Account__c != null){
				leadsToProcess.add(l);
				leadIdsToProcess.add(l.Id);
				agentIdsToProcess.add(l.Agent_Account__c);
			}
		}

		if(leadIdsToProcess.size() > 0){
			List<Contact> agentContacts = [Select Id, AccountId from Contact where AccountId in :agentIdsToProcess];
			List<Interest_List__c> cois = [Select Id, Lead__c, Community_Site__c from Interest_List__c where Lead__c in :leadIdsToProcess];
			List<Interest_List__c> coisForUpdate = new List<Interest_List__c>();
			List<Task> tasks = [Select Id, whoId from Task where whoId in :leadIdsToProcess];
			List<Task> tasksForUpdate = new List<Task>();
			List<Event> events = [Select Id, whoId from Event where whoId in :leadIdsToProcess];
			List<Event> eventsForUpdate = new List<Event>();
			List<Site_Visit__c> visits = [Select Id, Lead__c from Site_Visit__c where Lead__c in :leadIdsToProcess];
			List<Site_Visit__c> visitsForUpdate = new List<Site_Visit__c>();
			List<Note> notes = [Select Id, ParentId, Body, OwnerId, Title, IsPrivate from Note where ParentId in :leadIdsToProcess];
			List<Note> newNotes = new List<Note>();
			List<Attachment> attachments = [Select Id, ParentId, Body, IsPrivate, Name, Description, OwnerId from Attachment where ParentId in :leadIdsToProcess];
			List<Attachment> newAttachments = new List<Attachment>();
			List<Account> agentAccountsForUpdate = new List<Account>();

			Map<Id,Set<Id>> agentCOIMap = new Map<Id,Set<Id>>();

			for(Interest_List__c il : [Select Id, Account__c, Community_Site__c from Interest_List__c where Account__c in :agentIdsToProcess]){
				Set<Id> coiIds = new Set<Id>();
				if(agentCOIMap.get(il.Account__c) != null){
					coiIds = agentCOIMap.get(il.Account__c);
				}
				coiIds.add(il.Community_Site__c);
				agentCOIMap.put(il.Account__c,coiIds);
			}

			for(Lead l : leadsToProcess){
				// Get Agent Contact Id
				Id contactId;
				for(Contact c : agentContacts){
					if(c.AccountId == l.Agent_Account__c){
						contactId = c.Id;
						break;
					}
				}
				//Update COI Records
				Set<Id> agentCOIs = new Set<Id>();
				if(agentCOIMap.get(l.Agent_Account__c) != null){
					agentCOIs = agentCOIMap.get(l.Agent_Account__c);
				}

				for(Interest_List__c coi : cois){
					if(coi.Lead__c == l.Id){
						if(agentCOIs != null && !agentCOIs.contains(coi.Community_Site__c)){
							coi.Account__c = l.Agent_Account__c;
							if(contactId != null){
								coi.Contact__c = contactId;
							}
							coi.Lead__c = null;
							coisForUpdate.add(coi);
						}						
					}
				}

				//Update Task records
				for(Task t : tasks){
					if(t.whoId == l.Id){
						t.WhatId = l.Agent_Account__c;
						if(contactId != null){
							t.WhoId = contactId;
						}
						tasksForUpdate.add(t);
					}
				}

				//Update Event records
				for(Event e : events){
					if(e.whoId == l.Id){
						e.WhatId = l.Agent_Account__c;
						if(contactId != null){
							e.WhoId = contactId;
						}
						eventsForUpdate.add(e);
					}
				}	
				
				//Update Site Visit records
				for(Site_Visit__c sv : visits){
					if(sv.Lead__c == l.Id){
						sv.Account__c = l.Agent_Account__c;
						if(contactId != null){
							sv.Contact__c = contactId;
						}
						sv.Lead__c = null;
						visitsForUpdate.add(sv);
					}
				} 

				//Copy Notes - notes cannot be reparented after insert
				for(Note n : notes){
					if(n.ParentId == l.Id){
						Id parentId;
						if(contactId != null){
							parentId = contactId;
						}else{
							parentId = l.Agent_Account__c;
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
				for(Attachment at : attachments){
					if(at.ParentId == l.Id){
						Id parentId;
						if(contactId != null){
							parentId = contactId;
						}else{
							parentId = l.Agent_Account__c;
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

				//sync Agent Account	
				Account acct = new Account(Id = l.Agent_Account__c);
					acct.Agent_First_Name__c = l.Broker_First_Name__c;
					acct.Agent_Last_Name__c = l.Broker_Last_Name__c;
					acct.Agent_License__c = l.Broker_License__c;
					acct.Phone = l.Broker_Phone__c;
					acct.Email__c = l.Broker_Email__c;
					acct.Broker_s_Agency__c = l.Brokers_Agency_Name__c;
					acct.Broker_Agency_Other__c = l.Broker_Agency_Other__c;
					acct.Broker_License__c = l.Broker_License2__c;
					agentAccountsForUpdate.add(acct);  				
         }

			//DML Statements
			if(coisForUpdate.size() > 0){
   			update coisForUpdate;
   		}	
   		if(tasksForUpdate.size() > 0){
   			update tasksForUpdate;
   		}
   		if(eventsForUpdate.size() > 0){
   			update eventsForUpdate;
   		}
   		if(visitsForUpdate.size() > 0){
   			update visitsForUpdate;
   		}
   		if(newNotes.size() > 0){
   			insert newNotes;
   		}
   		if(newAttachments.size() > 0){
   			insert newAttachments;
   		}
   		if(agentAccountsForUpdate.size() > 0){
   			update agentAccountsForUpdate;
   		}
   		if(leadsToProcess.size() > 0){
   			delete leadsToProcess;
         }
   	}	
	}
	
	
	global void finish(Database.BatchableContext BC) {
		
	}

	global void execute( SchedulableContext SC ) {
    	Database.executeBatch( new AgentLeadCleanUpBatch() ); 
    }
	
}