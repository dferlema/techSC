import os
import re

def process_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Avoid processing if it doesn't have '.when('
    if '.when(' not in content:
        return

    original_content = content

    # Replace loading
    content = re.sub(
        r'loading:\s*\(\)\s*=>\s*const\s*Center\(\s*child:\s*CircularProgressIndicator\(\)\s*\),?',
        'loading: () => const AppLoadingIndicator(),',
        content
    )

    # Replace error simple Center(child: Text(...))
    content = re.sub(
        r'error:\s*\(([^,]+),\s*[^)]+\)\s*=>\s*Center\(\s*child:\s*Text\([^\)]+\)\s*\),?',
        r'error: (\1, _) => AppErrorWidget(error: \1),',
        content
    )

    # If changed, ensure imports are present
    if content != original_content:
        imports = []
        if 'AppLoadingIndicator' in content and 'app_loading_indicator.dart' not in content:
            imports.append("import 'package:techsc/core/widgets/app_loading_indicator.dart';")
        if 'AppErrorWidget' in content and 'app_error_widget.dart' not in content:
            imports.append("import 'package:techsc/core/widgets/app_error_widget.dart';")
        
        if imports:
            # find last import
            lines = content.split('\n')
            last_import_idx = -1
            for i, line in enumerate(lines):
                if line.startswith('import '):
                    last_import_idx = i
            
            if last_import_idx != -1:
                # insert after last import
                lines = lines[:last_import_idx+1] + imports + lines[last_import_idx+1:]
                content = '\n'.join(lines)
            else:
                content = '\n'.join(imports) + '\n\n' + content

        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
