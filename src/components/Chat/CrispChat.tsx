import { useEffect } from 'react';
import { useAuth } from '../../hooks/useAuth';

declare global {
  interface Window {
    $crisp: any[];
    CRISP_WEBSITE_ID: string;
  }
}

export default function CrispChat() {
  const { session } = useAuth();

  useEffect(() => {
    // Initialize Crisp
    window.$crisp = [];
    window.CRISP_WEBSITE_ID = "YOUR_WEBSITE_ID"; // Replace with your Crisp Website ID

    // Load Crisp script
    (function() {
      const d = document;
      const s = d.createElement("script");
      s.src = "https://client.crisp.chat/l.js";
      s.async = true;
      d.getElementsByTagName("head")[0].appendChild(s);
    })();

    // Configure Crisp when session changes
    if (session?.user) {
      window.$crisp.push(["set", "user:email", session.user.email]);
      window.$crisp.push(["set", "user:nickname", session.user.email?.split('@')[0]]);
      window.$crisp.push(["set", "session:data", [
        ["userRole", session.user.user_metadata?.role || 'user'],
        ["userId", session.user.id]
      ]]);
    }

    return () => {
      // Cleanup Crisp on unmount
      const script = document.querySelector('script[src="https://client.crisp.chat/l.js"]');
      if (script) {
        script.remove();
      }
      delete window.$crisp;
      delete window.CRISP_WEBSITE_ID;
    };
  }, [session]);

  return null;
}