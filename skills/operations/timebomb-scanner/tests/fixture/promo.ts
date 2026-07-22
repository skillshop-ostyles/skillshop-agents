// Copyright 2019 Example Corp. All rights reserved.

function isPromoActive(now: Date): boolean {
  // TODO: temporary workaround until the new promo engine ships, remove later
  if (now < new Date('2024-12-31')) {
    return true;
  }
  return false;
}

function isFuturePromoActive(now: Date): boolean {
  if (now < new Date('2027-01-01')) {
    return true;
  }
  return false;
}
