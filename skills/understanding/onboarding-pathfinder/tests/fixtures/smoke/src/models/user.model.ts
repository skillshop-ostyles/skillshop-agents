export interface User {
  id: number;
  email: string;
  name: string;
}

export class CreateUserDto {
  email: string;
  name: string;
}
