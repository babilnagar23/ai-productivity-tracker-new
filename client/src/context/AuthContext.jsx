import  { createContext, useState, useEffect, useContext, useRef, useCallback } from 'react';
import { apiFetch, logout as apiLogout } from '../services/api';

const AuthContext = createContext(null);

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  // Guard against StrictMode double-mount
  const fetchGuard = useRef(false);

  const fetchUser = useCallback(async () => {
    try {
      const token = localStorage.getItem('token');
      if (!token) {
        setLoading(false);
        return;
      }
      const res = await apiFetch('/auth/me');
      if (res.success) {
        setUser(res.data);
        setIsAuthenticated(true);
      } else {
        localStorage.removeItem('token');
      }
    } catch (err) {
      console.error('Error fetching user:', err);
      localStorage.removeItem('token');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    // Prevent StrictMode double-fetch on initial mount
    if (fetchGuard.current) return;
    fetchGuard.current = true;
    fetchUser();
  }, [fetchUser]);

  // Helper: set user state directly from a login/register response
  const setAuthFromResponse = (resData) => {
    setUser(resData.user);
    setIsAuthenticated(true);
    setLoading(false);
  };

  const login = async (email, password) => {
    setLoading(true);
    try {
      const res = await apiFetch('/auth/login', {
        method: 'POST',
        body: JSON.stringify({ email, password }),
      });
      if (res.success && res.data?.token) {
        localStorage.setItem('token', res.data.token);
        // Use user data from login response directly — no extra /auth/me call
        if (res.data.user) {
          setAuthFromResponse(res.data);
        } else {
          await fetchUser();
        }
        return { success: true, user: res.data.user };
      }
      setLoading(false);
      return { success: false, error: res.message || 'Login failed' };
    } catch (err) {
      setLoading(false);
      return { success: false, error: err.message || 'Login failed' };
    }
  };

  const register = async (name, email, password) => {
    setLoading(true);
    try {
      const res = await apiFetch('/auth/register', {
        method: 'POST',
        body: JSON.stringify({ name, email, password }),
      });
      if (res.success && res.data?.token) {
        localStorage.setItem('token', res.data.token);
        // Use user data from register response directly
        if (res.data.user) {
          setAuthFromResponse(res.data);
        } else {
          await fetchUser();
        }
        return { success: true, user: res.data.user };
      }
      setLoading(false);
      return { success: false, error: res.message || 'Registration failed' };
    } catch (err) {
      setLoading(false);
      return { success: false, error: err.message || 'Registration failed' };
    }
  };

  const completeOTPRegistration = async (email, password, confirm_password) => {
    setLoading(true);
    try {
      const res = await apiFetch('/auth/complete-registration', {
        method: 'POST',
        body: JSON.stringify({ email, password, confirm_password }),
      });
      if (res.success && res.data?.token) {
        localStorage.setItem('token', res.data.token);
        // Use user data from registration response directly
        if (res.data.user) {
          setAuthFromResponse(res.data);
        } else {
          await fetchUser();
        }
        return { success: true, user: res.data.user };
      }
      setLoading(false);
      return { success: false, error: res.message || 'Registration failed' };
    } catch (err) {
      setLoading(false);
      return { success: false, error: err.message || 'Registration failed' };
    }
  };

  const logout = async () => {
    try {
      await apiLogout();
    } catch (err) {
      console.error("Logout error", err);
    } finally {
      localStorage.removeItem('token');
      setUser(null);
      setIsAuthenticated(false);
    }
  };

  return (
    <AuthContext.Provider value={{ user, loading, isAuthenticated, login, register, completeOTPRegistration, logout, refreshUser: fetchUser }}>
      {children}
    </AuthContext.Provider>
  );

};

export const useAuth = () => useContext(AuthContext);
