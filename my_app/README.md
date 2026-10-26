Name: Femi Ijimayowa (working alone, team of one) Track: Undergraduate Task:

Question 1: Trace the tip feature from button tap to displayed text

When I tap "Get a signup tip," the \_loadTip() method runs. It sets \_tipStatus to loading and calls setState, so Flutter rebuilds the screen. The button disappears and a spinning circle (CircularProgressIndicator) shows in its place. After about one second the service returns the tip, the text is cut to 240 characters, and \_tipStatus becomes success. The screen then shows a label saying it is a mock tip and the tip text, plus a "New tip" button.

If anything goes wrong, the catch block sets \_tipStatus to error. The screen then shows "Couldn't get a tip right now." and a Retry button. Tapping Retry runs \_loadTip() again, so the user can try again without restarting the app.

Question 2: Why validation must stay local

Validation has to stay on the device because it is a set of fixed rules (is there an "@", is the password at least 6 characters), and those rules should give the same answer every time. An AI can be wrong, slow, offline, or tricked by the text it receives. If signup depended on the AI, nobody could sign up when the AI was down.

A bad decision would be the AI approving a signup with an email like "hello" and a password like "1". The account would be created with an email that can't receive messages and a password that is easy to guess. That is why the AI is only allowed to give a tip and the local validators make the real decision.

What the app does

A signup screen with Full Name, Email, and Password fields. Each field checks its own input on the device. If everything is valid, a green message appears. There is also a "Get a signup tip" button that shows a short password tip.

Visual theme choice: I replaced the old primarySwatch with ColorScheme.fromSeed(seedColor: Colors.purple), which builds a Material 3 color scheme from one purple color.

AI use note: I used AI to grammatically fix my sentences (Clauide)
