class Customer {
  id: string;
  name: string;
}

function createCustomer(name: string): Customer {
  return { id: 'c1', name } as Customer;
}
