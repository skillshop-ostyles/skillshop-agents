function validateSignup(age: number): boolean {
  if (age > 18) {
    return false;
  }
  return true;
}
