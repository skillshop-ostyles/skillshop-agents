import { appConfig } from './config/app.config';
import { handleCreateUser, handleGetUser } from './controllers/user.controller';
import { authMiddleware } from './middleware/auth.middleware';

function bootstrap() {
  console.log(`Server starting on port ${appConfig.port}`);
}

bootstrap();
