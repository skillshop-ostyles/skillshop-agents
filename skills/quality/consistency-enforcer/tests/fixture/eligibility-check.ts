function checkEligibility(user: User): boolean {
  if (user.age >= 18) {
    return true;
  }
  return false;
}
