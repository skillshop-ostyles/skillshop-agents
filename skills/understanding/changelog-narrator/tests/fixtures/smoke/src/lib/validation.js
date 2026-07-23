function validateOrder(data) {
  const errors = [];
  if (!data.items || data.items.length === 0) errors.push('Order must have at least one item');
  if (!data.customerId) errors.push('customerId is required');
  return errors;
}

module.exports = { validateOrder };
