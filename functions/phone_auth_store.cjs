'use strict';

// M425: no finance collections are referenced here. All identity registry
// changes and attempt limits are atomic Firestore transactions.
function createPhoneAuthStore(firestore) {
  const owners = firestore.collection('waffraPhoneBindings');
  const identities = firestore.collection('waffraPhoneCredentials');
  const attempts = firestore.collection('waffraPhoneLoginAttempts');
  return {
    async bindPhone({key,uid,passwordDigest,at}) {
      return firestore.runTransaction(async(tx) => {
        const ownerRef = owners.doc(key), userRef = identities.doc(uid);
        const [owner,user] = await Promise.all([
          tx.get(ownerRef),tx.get(userRef),
        ]);
        if (owner.exists && owner.data()?.uid !== uid) return false;
        // Never overwrite a previous linked mobile without an independent
        // verified recovery/migration protocol.
        if (user.exists && user.data()?.phoneKey !== key) return false;
        tx.set(ownerRef,{uid,version:1,updatedAt:at});
        tx.set(userRef,{
          phoneKey:key,digest:passwordDigest,version:1,updatedAt:at,
        });
        return true;
      });
    },
    async phoneOwner(key) {
      const result = await owners.doc(key).get();
      return result.exists ? result.data() : null;
    },
    async passwordRecord(uid) {
      if (typeof uid !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(uid)) {
        return null;
      }
      const result = await identities.doc(uid).get();
      return result.exists ? result.data() : null;
    },
    async attempt({key,nowMs,windowMs,maxAttempts}) {
      return firestore.runTransaction(async(tx) => {
        const ref = attempts.doc(key);
        const doc = await tx.get(ref);
        const data = doc.exists ? doc.data() : null;
        const started = Number(data?.started) || 0;
        const fresh = started <= 0 || nowMs - started >= windowMs ||
          nowMs < started;
        const count = fresh ? 0 : (Number(data?.count) || 0);
        // Refuse and record nothing if the window already exhausted.
        if (count >= maxAttempts) return false;
        tx.set(ref,{
          started:fresh ? nowMs : started,
          count:count + 1,
          expiresAt:new Date(nowMs + windowMs * 2),
        });
        return true;
      });
    },
    async resetPassword({uid,key,digest,at}) {
      return firestore.runTransaction(async(tx) => {
        const ownerRef = owners.doc(key), userRef = identities.doc(uid);
        const [owner,user] = await Promise.all([
          tx.get(ownerRef),tx.get(userRef),
        ]);
        if (!owner.exists || owner.data()?.uid !== uid ||
            !user.exists || user.data()?.phoneKey !== key) return false;
        tx.set(userRef,{phoneKey:key,digest,version:1,updatedAt:at});
        return true;
      });
    },
  };
}
module.exports={createPhoneAuthStore};
