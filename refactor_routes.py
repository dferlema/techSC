import os
import re

def process_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    replacements = {
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*CartPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/cart');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*MyOrdersPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/my-orders');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*QuoteListPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/quotes');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*AdminPanelPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/admin');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*ReportsPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/reports');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*SettingsPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/settings');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*TechnicianDashboard\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/technician');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*InventoryReportsPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/inventory-reports');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*SupplierManagementPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/supplier-management');",
        r"Navigator\.push\(\s*context,\s*MaterialPageRoute\(\s*builder:\s*\((?:_|context)\)\s*=>\s*const\s*NotificationsPage\(\)\s*,?\)\s*,?\)?;": "Navigator.pushNamed(context, '/notifications');",
    }

    for patt, repl in replacements.items():
        content = re.sub(patt, repl, content, flags=re.MULTILINE)

    if content != original_content:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart') and file != 'main.dart':
            process_file(os.path.join(root, file))
