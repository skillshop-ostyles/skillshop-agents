import { getLegacyData } from './data/legacyRepo';

function handleLegacyRequest(id: string): Promise<any> {
  return getLegacyData(id)
    .then(function(data: any) {
      const result = data || {};
      return result;
    })
    .catch(function(error: any) {
      console.error('Legacy error: ' + error.message);
      return null;
    });
}

module.exports = { handleLegacyRequest };
