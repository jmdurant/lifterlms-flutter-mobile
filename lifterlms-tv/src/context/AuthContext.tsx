import React, {createContext, useContext, useState, useEffect, useCallback} from 'react';
import api from '../api/lifterlms';

// Configure API — update these for your site
const SITE_URL = 'https://vr2fit.com';
const CONSUMER_KEY = 'ck_9488a29dab0ee72d70e1dec012db499b57052b3d';
const CONSUMER_SECRET = 'cs_730fe825c949a4978d8640bc1ae0ca09069fd84f';

interface User {
  token: string;
  user_display_name: string;
  user_email: string;
  user_nicename: string;
}

interface AuthContextType {
  user: User | null;
  isLoading: boolean;
  login: (username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  isLoading: true,
  login: async () => {},
  logout: async () => {},
});

export const useAuth = () => useContext(AuthContext);

export const AuthProvider: React.FC<{children: React.ReactNode}> = ({children}) => {
  const [user, setUser] = useState<User | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    api.configure(SITE_URL, CONSUMER_KEY, CONSUMER_SECRET);
    api.restoreSession().then(savedUser => {
      if (savedUser) {
        setUser(savedUser);
      }
      setIsLoading(false);
    });
  }, []);

  const login = useCallback(async (username: string, password: string) => {
    const data = await api.login(username, password);
    setUser(data);
  }, []);

  const logout = useCallback(async () => {
    await api.logout();
    setUser(null);
  }, []);

  return (
    <AuthContext.Provider value={{user, isLoading, login, logout}}>
      {children}
    </AuthContext.Provider>
  );
};
