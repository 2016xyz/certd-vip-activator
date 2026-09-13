import {assert} from 'chai'
import {resolveDomainBySoaRecord} from "../src/util.js"
describe('dns', () => {
    it('resolveDomainBySoaRecord', async () => {
        const resp = await resolveDomainBySoaRecord("a.corp.smartdeer.com")

        assert.equal(resp, "smartdeer.com")

    });

})