export interface PaymentResult {
  success: boolean;
  transactionId?: string;
  error?: string;
}

export async function processPayment(amount: number, token: string): Promise<PaymentResult> {
  if (amount <= 0) return { success: false, error: 'Invalid amount' };
  if (!token) return { success: false, error: 'Missing payment token' };
  return { success: true, transactionId: `txn_${Date.now()}` };
}
