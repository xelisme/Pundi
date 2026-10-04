/// Copyright and licensing metadata for Pundi.
///
/// Single source of truth so the About footer, the license dialog and the
/// LICENSE file cannot drift apart. Change these two constants and the whole
/// app follows.
library;

/// Shown in the About footer and in the license dialog.
const String appName = 'Pundi';

const String appVersion = '1.0.0';

const String appCopyrightHolder = 'xelisme';

/// SPDX identifier, short form for the footer.
const String appLicenseName = 'MIT';

/// Full license text. Kept verbatim to the LICENSE file so the in-app copy is
/// the actual grant rather than a summary that only looks like one.
const String appLicenseText = '''
MIT License

Copyright (c) $appCopyrightYear $appCopyrightHolder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''';

/// Published year, kept in sync with the LICENSE file. Update once a year
/// rather than hardcoding a second copy of it in the widget tree.
const int appCopyrightYear = 2026;

/// One-line notice for the footer, e.g. "© 2026 xelisme · Lisensi MIT".
String get appCopyrightNotice =>
    '© $appCopyrightYear $appCopyrightHolder · Lisensi $appLicenseName';