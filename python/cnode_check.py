import requests
import time
import json
from datetime import datetime
import os
from typing import Optional

class TelegramNotifier:
    def __init__(self, bot_token: str, chat_id: str):
        """
        Initialize Telegram notifier
        
        Args:
            bot_token: Your Telegram bot token
            chat_id: Your Telegram chat ID
        """
        self.bot_token = bot_token
        self.chat_id = chat_id
        self.api_url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    
    def send_message(self, message: str):
        """Send message to Telegram"""
        try:
            payload = {
                'chat_id': self.chat_id,
                'text': message,
                'parse_mode': 'HTML'
            }
            response = requests.post(self.api_url, json=payload)
            response.raise_for_status()
            return True
        except Exception as e:
            print(f"Error sending Telegram message: {e}")
            return False

class CardanoNodeMonitor:
    def __init__(self, telegram_notifier: TelegramNotifier, check_interval: int = 3600):
        """
        Initialize the Cardano node release monitor.
        
        Args:
            telegram_notifier: TelegramNotifier instance for notifications
            check_interval: Time between checks in seconds (default 1 hour)
        """
        self.check_interval = check_interval
        self.api_url = "https://api.github.com/repos/IntersectMBO/cardano-node/releases/latest"
        self.last_release: Optional[str] = None
        self.cache_file = "cardano_node_last_release.json"
        self.telegram = telegram_notifier
        
        # Load last known release from cache if it exists
        self._load_cache()
    
    def _load_cache(self):
        """Load the last known release from cache file."""
        try:
            if os.path.exists(self.cache_file):
                with open(self.cache_file, 'r') as f:
                    data = json.load(f)
                    self.last_release = data.get('last_release')
        except Exception as e:
            print(f"Error loading cache: {e}")
    
    def _save_cache(self):
        """Save the last known release to cache file."""
        try:
            with open(self.cache_file, 'w') as f:
                json.dump({'last_release': self.last_release}, f)
        except Exception as e:
            print(f"Error saving cache: {e}")
    
    def _parse_version(self, tag_name: str) -> tuple:
        """Parse Cardano node version from tag name."""
        try:
            version = tag_name.lstrip('v')
            version_parts = version.split('-')
            main_version = tuple(map(int, version_parts[0].split('.')))
            is_pre = len(version_parts) > 1
            return (main_version, is_pre)
        except Exception:
            return ((0, 0, 0), False)

    def check_new_release(self) -> Optional[dict]:
        """Check for new Cardano node releases."""
        try:
            headers = {
                'Accept': 'application/vnd.github.v3+json',
                # Add your GitHub token here if needed:
                # 'Authorization': 'token YOUR_GITHUB_TOKEN'
            }
            
            print(f"\nChecking for new releases at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            response = requests.get(self.api_url, headers=headers)
            response.raise_for_status()
            
            latest_release = response.json()
            latest_tag = latest_release['tag_name']
            
            if self.last_release is None:
                print(f"First run - current version is {latest_tag}")
                self.last_release = latest_tag
                self._save_cache()
                return None
            elif latest_tag != self.last_release:
                self.last_release = latest_tag
                self._save_cache()
                return latest_release
            else:
                print(f"No new releases found. Current version: {latest_tag}")
            
            return None
            
        except requests.exceptions.RequestException as e:
            print(f"Error checking releases: {e}")
            self.telegram.send_message(f"⚠️ Error checking Cardano node releases: {e}")
            return None

    def format_telegram_message(self, release_info: dict) -> str:
        """Format release information for Telegram message."""
        version_info = self._parse_version(release_info['tag_name'])
        
        message = [
            f"🔔 <b>New Cardano Node Release!</b>",
            f"\n<b>Version:</b> {release_info['tag_name']}",
            f"<b>Name:</b> {release_info['name']}"
        ]
        
        if version_info[1]:
            message.append("\n⚠️ <b>Note:</b> This is a pre-release version")
        
        message.append(f"\n<b>Release URL:</b> {release_info['html_url']}")
        
        if release_info.get('assets'):
            message.append("\n<b>Available Downloads:</b>")
            for asset in release_info['assets']:
                message.append(f"• {asset['name']}")
        
        # Truncate release notes if too long for Telegram
        notes = release_info['body']
        if len(notes) > 500:
            notes = notes[:497] + "..."
        message.append(f"\n<b>Release Notes:</b>\n{notes}")
        
        # Check for important keywords
        important_keywords = ['breaking change', 'upgrade required', 'mandatory upgrade']
        release_notes_lower = release_info['body'].lower()
        for keyword in important_keywords:
            if keyword in release_notes_lower:
                message.append(f"\n⚠️ <b>IMPORTANT:</b> This release contains a {keyword}!")
        
        return "\n".join(message)
    
    def notify(self, release_info: dict):
        """Handle notification when new release is found."""
        # Console output
        print("\n" + "="*50)
        print(f"New Cardano Node Release at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}!")
        print("="*50)
        print(f"Version: {release_info['tag_name']}")
        print(f"Name: {release_info['name']}")
        print(f"URL: {release_info['html_url']}")
        print("\n" + "="*50 + "\n")
        
        # Telegram notification
        telegram_message = self.format_telegram_message(release_info)
        self.telegram.send_message(telegram_message)
    
    def start_monitoring(self):
        """Start the continuous monitoring loop."""
        print(f"Starting Cardano Node Release Monitor")
        print(f"Repository: IntersectMBO/cardano-node")
        print(f"Check interval: Every {self.check_interval//3600} hour(s)")
        print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("="*50)
        
        # Send startup notification to Telegram
        self.telegram.send_message(
            "🟢 Cardano Node Release Monitor started\n"
            f"Checking every {self.check_interval//3600} hour(s)"
        )
        
        while True:
            new_release = self.check_new_release()
            if new_release:
                self.notify(new_release)
            
            next_check = datetime.now().timestamp() + self.check_interval
            print(f"Next check at: {datetime.fromtimestamp(next_check).strftime('%Y-%m-%d %H:%M:%S')}")
            time.sleep(self.check_interval)

if __name__ == "__main__":
    # Your Telegram credentials - Replace these with your actual values
    TELEGRAM_BOT_TOKEN = "<your telegram bot token>"
    TELEGRAM_CHAT_ID = "<your telegram chat ID>"
    
    # Initialize Telegram notifier
    telegram = TelegramNotifier(TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID)
    
    # Initialize and start monitor
    monitor = CardanoNodeMonitor(
        telegram_notifier=telegram,
        check_interval=3600  # Check every hour
    )
    
    monitor.start_monitoring()
