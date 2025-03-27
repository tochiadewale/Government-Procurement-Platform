import { describe, it, expect, beforeEach } from 'vitest';
import {
  initSimnet,
  getAccounts,
  callReadOnlyFn,
  callPublicFn
} from './test-utils';

describe('RFP Publication Contract', () => {
  let simnet;
  let accounts;
  let deployer;
  let government;
  let bidder;
  
  beforeEach(async () => {
    // Initialize the simnet and accounts
    simnet = await initSimnet();
    accounts = getAccounts(simnet);
    [deployer, government, bidder] = accounts;
    
    // Deploy the RFP publication contract
    await simnet.deployContract('rfp-publication', 'contracts/rfp-publication.clar');
    
    // Add government as an authorized entity
    await callPublicFn(
        simnet,
        'rfp-publication',
        'add-authorized-entity',
        [government.address, 'GOVERNMENT'],
        deployer.address
    );
  });
  
  it('should allow authorized entities to publish RFPs', async () => {
    const title = 'New Highway Construction';
    const description = 'Construction of a new highway connecting City A and City B';
    const department = 'Transportation';
    const budget = 1000000;
    const deadline = 100; // 100 blocks from now
    
    const result = await callPublicFn(
        simnet,
        'rfp-publication',
        'publish-rfp',
        [title, description, department, budget, deadline],
        government.address
    );
    
    expect(result.success).toBe(true);
    expect(result.result).toBe('(ok u1)');
    
    // Verify the RFP was stored correctly
    const rfpResult = await callReadOnlyFn(
        simnet,
        'rfp-publication',
        'get-rfp',
        [1],
        government.address
    );
    
    const rfp = rfpResult.result.value;
    expect(rfp.title).toBe(title);
    expect(rfp.description).toBe(description);
    expect(rfp.department).toBe(department);
    expect(rfp.budget).toBe(budget);
    expect(rfp.deadline).toBe(deadline);
    expect(rfp.status).toBe('OPEN');
    expect(rfp['created-by']).toBe(government.address);
  });
  
  it('should not allow unauthorized entities to publish RFPs', async () => {
    const title = 'New Highway Construction';
    const description = 'Construction of a new highway connecting City A and City B';
    const department = 'Transportation';
    const budget = 1000000;
    const deadline = 100; // 100 blocks from now
    
    const result = await callPublicFn(
        simnet,
        'rfp-publication',
        'publish-rfp',
        [title, description, department, budget, deadline],
        bidder.address
    );
    
    expect(result.success).toBe(false);
    expect(result.error).toBe('u403');
  });
  
  it('should allow updating RFP status by creator', async () => {
    // First publish an RFP
    await callPublicFn(
        simnet,
        'rfp-publication',
        'publish-rfp',
        ['Test RFP', 'Description', 'Department', 1000, 100],
        government.address
    );
    
    // Now update its status
    const result = await callPublicFn(
        simnet,
        'rfp-publication',
        'update-rfp-status',
        [1, 'CLOSED'],
        government.address
    );
    
    expect(result.success).toBe(true);
    expect(result.result).toBe('(ok true)');
    
    // Verify the status was updated
    const rfpResult = await callReadOnlyFn(
        simnet,
        'rfp-publication',
        'get-rfp',
        [1],
        government.address
    );
    
    const rfp = rfpResult.result.value;
    expect(rfp.status).toBe('CLOSED');
  });
  
  it('should not allow non-creators to update RFP status', async () => {
    // First publish an RFP
    await callPublicFn(
        simnet,
        'rfp-publication',
        'publish-rfp',
        ['Test RFP', 'Description', 'Department', 1000, 100],
        government.address
    );
    
    // Try to update status as non-creator
    const result = await callPublicFn(
        simnet,
        'rfp-publication',
        'update-rfp-status',
        [1, 'CLOSED'],
        bidder.address
    );
    
    expect(result.success).toBe(false);
    expect(result.error).toBe('u403');
  });
});
