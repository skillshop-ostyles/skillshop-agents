function createUserHandler(req: any) {
  const body = req.body as CreateUserRequest;

  // Clean match
  const id = body.id;
  const clean = { id, name: body.name, status: 'active' };

  // VIOLATION 1: email can be undefined despite declared NOT NULL
  const email = body.email || undefined;
  const user1 = { id, name: body.name, email };

  // VIOLATION 2: age is parsed from string, but schema says number
  const age = parseInt(body.age);
  const user2 = { id, name: body.name, age };

  return { user: clean };
}
