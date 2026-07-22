export interface CreateOrderDto {
  customerId: string;
  total: number;
  couponCode?: string;
}
