import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import { ThemeProvider } from './context/ThemeContext';
import ProtectedRoute from './components/ProtectedRoute';

// Auth pages (public)
import LandingPage from './pages/LandingPage';
import Login from './pages/Login';
import Signup from './pages/Signup';
import ForgotPassword from './pages/ForgotPassword';
import ResetPassword from './pages/ResetPassword';
import VerifyOTP from './pages/VerifyOTP';
import CreatePassword from './pages/CreatePassword';

// App pages (protected)
import Dashboard from './pages/Dashboard';
import Todos from './pages/Todos';
import RoutineTracker from './pages/RoutineTracker';
import Focus from './pages/Focus';
import CalendarPage from './pages/CalendarPage';
import Analytics from './pages/Analytics';
import AIAssistant from './pages/AIAssistant';
import Achievements from './pages/Achievements';
import Notifications from './pages/Notifications';
import Profile from './pages/Profile';
import Settings from './pages/Settings';
import Customization from './pages/Customization';
import GoogleCallback from './pages/GoogleCallback';

const Protected = ({ children }) => <ProtectedRoute>{children}</ProtectedRoute>;

function App() {
  return (
    <ThemeProvider>
      <AuthProvider>
        <Router>
          <Routes>
            {/* ── Public ──────────────────────────────────── */}
            <Route path="/"                        element={<LandingPage />} />
            <Route path="/login"                   element={<Login />} />
            <Route path="/signup"                  element={<Signup />} />
            <Route path="/verify-otp"              element={<VerifyOTP />} />
            <Route path="/create-password"         element={<CreatePassword />} />
            <Route path="/forgot-password"         element={<ForgotPassword />} />
            <Route path="/reset-password/:uid/:token" element={<ResetPassword />} />

            {/* ── Protected ────────────────────────────────── */}
            <Route path="/dashboard"    element={<Protected><Dashboard /></Protected>} />
            <Route path="/todos"        element={<Protected><Todos /></Protected>} />            <Route path="/routines"     element={<Protected><RoutineTracker /></Protected>} />
            <Route path="/focus"        element={<Protected><Focus /></Protected>} />
            <Route path="/calendar"     element={<Protected><CalendarPage /></Protected>} />
            <Route path="/analytics"    element={<Protected><Analytics /></Protected>} />
            <Route path="/ai-coach"     element={<Protected><AIAssistant /></Protected>} />
            <Route path="/achievements" element={<Protected><Achievements /></Protected>} />
            <Route path="/notifications" element={<Protected><Notifications /></Protected>} />
            <Route path="/profile"      element={<Protected><Profile /></Protected>} />
            <Route path="/settings"     element={<Protected><Settings /></Protected>} />
            <Route path="/customization" element={<Protected><Customization /></Protected>} />
            <Route path="/auth/google/callback" element={<Protected><GoogleCallback /></Protected>} />

            {/* ── Catch-all ────────────────────────────────── */}
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </Router>
      </AuthProvider>
    </ThemeProvider>
  );
}

export default App;
