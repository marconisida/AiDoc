AiDoc is a web application designed for management and automation purposes. It is built using modern technologies to ensure speed, security, and ease of use.

Technologies Used: Frontend: TypeScript, React, Vite, Tailwind CSS. Backend: Node.js and Supabase (for database and authentication). Additional Tools: Environment configuration using .env and Vite. Installation and Setup Instructions: Clone this repository to your local machine using the following command:

bash

git clone https://github.com/marconisida/AiDoc.git cd AiDoc

Install the required dependencies by running:

npm install Create a .env file in the project’s root directory using the .env.example file as a template.

Add your specific credentials:

Example:

makefile

VITE_SUPABASE_URL=your-project-url VITE_SUPABASE_ANON_KEY=your-anon-key JWT_SECRET=your-jwt-secret

Start the application locally by running:

npm run dev

Once the server is running, open your browser and visit:

http://localhost:5173

Features: Secure management and analysis. Authentication powered by Supabase with persistent sessions. Responsive and user-friendly design. Built-in retry mechanism for robust operation.

Disclaimer: This project is provided "as-is" without any guarantees or warranties. It is intended for demonstration and testing purposes only. By using this application, you agree that the author is not liable for any issues, errors, or malfunctions that may arise. Use it at your own risk and discretion.

Any setup, deployment, or maintenance of this project is entirely the responsibility of the user or the development team they choose to involve.

If you encounter any issues, I recommend seeking assistance from a qualified developer who can further tailor the application to your needs.
