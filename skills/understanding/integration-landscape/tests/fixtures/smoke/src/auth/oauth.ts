import passport from 'passport';
import { Strategy as Auth0Strategy } from 'passport-auth0';

passport.use(new Auth0Strategy({
  domain: process.env.AUTH0_DOMAIN ?? 'dev-xxx.us.auth0.com',
  clientID: process.env.AUTH0_CLIENT_ID,
  clientSecret: process.env.AUTH0_CLIENT_SECRET,
  callbackURL: '/auth/callback',
}, (accessToken, refreshToken, profile, done) => {
  done(null, profile);
}));
