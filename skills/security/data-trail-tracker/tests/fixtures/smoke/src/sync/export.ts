import axios from 'axios';
import { User } from '../models/user';

export async function syncUser(user: User) {
  await axios.post('https://external-api.example.com/users', {
    email: user.email,
    firstName: user.firstName,
  });
}
