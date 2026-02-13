copilot/fix-and-improve-bn88-project
# Contributing to BN88 New Clean

Thank you for your interest in contributing to the BN88 platform! This document provides guidelines and instructions for contributing to the project.

## 📋 Table of Contents

- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Standards](#code-standards)
- [Testing](#testing)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)

## 🚀 Getting Started

1. **Fork the repository** (if external contributor)
2. **Clone your fork**
   ```bash
   git clone <your-fork-url>
   cd ./-bn88-new-clean
   ```

3. **Set up development environment**
   - Follow setup instructions in [README.md](./README.md)
   - Ensure Node.js version matches `.nvmrc` (v18)
   - Install dependencies in both backend and frontend

4. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## 💻 Development Workflow

### Backend Development (`bn88-backend-v12`)

1. **Start the development server**
   ```bash
   cd bn88-backend-v12
   npm run dev
   ```

2. **Run database migrations**
   ```bash
   npx prisma migrate dev
   ```

3. **Seed test data**
   ```bash
   npm run seed:dev
   ```

4. **Type checking**
   ```bash
   npm run typecheck
   ```

### Frontend Development (`bn88-frontend-dashboard-v12`)

1. **Start the development server**
   ```bash
   cd bn88-frontend-dashboard-v12
   npm run dev
   ```

2. **Linting**
   ```bash
   npm run lint
   npm run lint:fix  # Auto-fix issues
   ```

3. **Type checking**
   ```bash
   npm run typecheck
   ```

### LINE Engagement Platform

1. **Start with Docker**
   ```bash
   cd line-engagement-platform
   docker compose up --build
   ```

## 📝 Code Standards

### TypeScript

- Use TypeScript for all new code
- Enable strict mode in `tsconfig.json`
- Avoid `any` types - use proper typing
- Use interfaces for object shapes
- Use type aliases for complex types

### Naming Conventions

- **Files**: Use kebab-case (`user-service.ts`)
- **Classes**: Use PascalCase (`UserService`)
- **Functions/Variables**: Use camelCase (`getUserById`)
- **Constants**: Use UPPER_SNAKE_CASE (`API_BASE_URL`)
- **Interfaces**: Use PascalCase with descriptive names (`UserInterface` or `IUser`)

### Code Style

- Use 2 spaces for indentation
- Use single quotes for strings
- Add semicolons at end of statements
- Maximum line length: 100 characters
- Use async/await over promises
- Use ES6+ features (arrow functions, destructuring, etc.)

### Comments

- Write clear, concise comments
- Document complex logic
- Use JSDoc for functions and classes
- Keep comments up-to-date with code changes

Example:
```typescript
/**
 * Authenticates a user with email and password
 * @param email - User's email address
 * @param password - User's password
 * @returns Authentication token and user data
 * @throws AuthenticationError if credentials are invalid
 */
async function authenticateUser(email: string, password: string): Promise<AuthResponse> {
  // Implementation
}
```

## 🧪 Testing

### Running Tests

**Backend**
```bash
cd bn88-backend-v12
npm test
```

**Frontend**
```bash
cd bn88-frontend-dashboard-v12
npm test
```

### Smoke Tests

Run smoke tests to verify basic functionality:
```powershell
.\smoke.ps1
```

### Deep Validation

Run comprehensive validation:
```powershell
.\deep-validation.ps1
```

### Writing Tests

- Write unit tests for business logic
- Write integration tests for API endpoints
- Aim for >80% code coverage
- Use descriptive test names
- Follow AAA pattern: Arrange, Act, Assert

Example:
```typescript
describe('UserService', () => {
  it('should create a new user with valid data', async () => {
    // Arrange
    const userData = { email: 'test@example.com', password: 'password123' };
    
    // Act
    const user = await userService.create(userData);
    
    // Assert
    expect(user.email).toBe(userData.email);
    expect(user.id).toBeDefined();
  });
});
```

## 📜 Commit Guidelines

### Commit Message Format

Use conventional commits format:
=======
 copilot/fix-bn88-project-issues-again
# 🤝 Contributing to BN88 New Clean

Thank you for your interest in contributing to BN88! This document provides guidelines and instructions for contributing to the project.

# 🤝 Contributing to BN88

Thank you for your interest in contributing to the BN88 platform! This document provides guidelines and instructions for contributing.
 main

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing](#testing)
- [Documentation](#documentation)

 copilot/fix-bn88-project-issues-again

---

 main
## 📜 Code of Conduct

### Our Pledge

 copilot/fix-bn88-project-issues-again
We are committed to providing a welcoming and inclusive environment for all contributors. Please:

- ✅ Be respectful and considerate
- ✅ Welcome newcomers and help them get started
- ✅ Accept constructive criticism gracefully
- ✅ Focus on what's best for the project and community

### Unacceptable Behavior

- ❌ Harassment or discriminatory language
- ❌ Trolling or insulting comments
- ❌ Publishing others' private information
- ❌ Any conduct that would be inappropriate in a professional setting

We are committed to providing a welcoming and inclusive experience for everyone. We expect all contributors to:

- Be respectful and considerate
- Use welcoming and inclusive language
- Accept constructive criticism gracefully
- Focus on what is best for the community
- Show empathy towards other community members

---
ช main

## 🚀 Getting Started

### Prerequisites

 copilot/fix-bn88-project-issues-again
Before contributing, ensure you have:

1. Read the `SETUP.md` guide
2. Successfully set up the development environment
3. Run the smoke tests: `.\smoke.ps1`
4. Familiarized yourself with the codebase

### Finding Issues to Work On

1. **Good First Issues:** Look for issues labeled `good first issue`
2. **Help Wanted:** Check issues labeled `help wanted`
3. **Bugs:** Look for issues labeled `bug`
4. **Features:** Check issues labeled `enhancement`

Before starting work:
- Comment on the issue to let others know you're working on it
- Wait for maintainer approval if it's a major change

## 💻 Development Workflow

### 1. Fork and Clone

```powershell
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/-bn88-new-clean.git
cd -bn88-new-clean

# Add upstream remote
git remote add upstream https://github.com/josho007237-max/-bn88-new-clean.git
```

### 2. Create a Branch

```powershell
# Update your main branch
git checkout main
git pull upstream main

# Create a feature branch
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test additions or modifications
- `chore/` - Maintenance tasks

### 3. Make Your Changes

Follow the coding standards (see below) and:

- Write clean, readable code
- Add comments for complex logic
- Update documentation as needed
- Add tests for new features
- Ensure all tests pass

### 4. Test Your Changes

```powershell
# Backend tests
cd bn88-backend-v12
npm run typecheck
npm run build

Before you start contributing, make sure you have:

1. **Completed the setup** - Follow [SETUP.md](SETUP.md)
2. **Read the documentation** - Familiarize yourself with [README.md](README.md)
3. **Understood the codebase** - Browse through the code structure

### Finding Issues to Work On

1. Check the [Issues](https://github.com/josho007237-max/-bn88-new-clean/issues) page
2. Look for issues labeled:
   - `good first issue` - Great for newcomers
   - `help wanted` - Need contributors
   - `bug` - Bug fixes needed
   - `enhancement` - New features

### Claiming an Issue

Before starting work:

1. **Comment on the issue** to let others know you're working on it
2. **Wait for assignment** or approval from maintainers
3. **Ask questions** if anything is unclear

---

## 💻 Development Workflow

### 1. Fork the Repository

Click the "Fork" button on GitHub to create your own copy.

### 2. Clone Your Fork

```bash
git clone https://github.com/YOUR_USERNAME/-bn88-new-clean.git
cd -bn88-new-clean
```

### 3. Add Upstream Remote

```bash
git remote add upstream https://github.com/josho007237-max/-bn88-new-clean.git
```

### 4. Create a Feature Branch

Always create a new branch for your work:

```bash
git checkout -b feature/your-feature-name

# Examples:
# git checkout -b feature/add-user-profile
# git checkout -b fix/login-token-expiration
# git checkout -b docs/update-api-documentation
```

**Branch naming conventions:**
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Adding tests
- `chore/` - Maintenance tasks

### 5. Make Your Changes

Work on your feature or fix following our [coding standards](#coding-standards).

### 6. Keep Your Branch Updated

Regularly sync with the main repository:

```bash
git fetch upstream
git rebase upstream/main
```

### 7. Test Your Changes

Before committing, ensure:

```bash
# Backend tests
cd bn88-backend-v12
npm run typecheck
 main
npm test

# Frontend tests
cd ../bn88-frontend-dashboard-v12
npm run typecheck
 copilot/fix-bn88-project-issues-again
npm run build
npm test

# Run smoke tests
cd ..
.\smoke.ps1
```

### 5. Commit Your Changes

Follow the commit message guidelines (see below):

```powershell
git add .
git commit -m "feat: add amazing new feature"
```

### 6. Push and Create PR

```powershell
# Push to your fork
git push origin feature/your-feature-name

# Create a Pull Request on GitHub
```

## 📝 Coding Standards

### General Principles

1. **Keep it Simple:** Write code that's easy to understand
2. **DRY (Don't Repeat Yourself):** Extract common logic
3. **Single Responsibility:** Each function should do one thing well
4. **Consistent Style:** Follow the existing code style

### TypeScript/JavaScript

- Use TypeScript for type safety
- Prefer `const` over `let`, avoid `var`
- Use meaningful variable and function names
- Add JSDoc comments for public APIs
- Handle errors properly - don't swallow them

#### Example:

```typescript
// Good
async function getUserById(userId: string): Promise<User | null> {
  try {
    const user = await prisma.user.findUnique({
      where: { id: userId }
    });
    return user;
  } catch (error) {
    logger.error('Failed to fetch user', { userId, error });
    throw new Error('Database query failed');
  }
}

// Bad
async function getUser(id: any) {
  try {
    return await prisma.user.findUnique({ where: { id } });
  } catch (e) {
    // Silent failure - bad!
  }
}
```

### React/Frontend

- Use functional components with hooks
- Extract complex logic into custom hooks
- Keep components small and focused
- Use proper TypeScript types
- Handle loading and error states

#### Example:

```typescript
// Good
interface UserProfileProps {
  userId: string;
}

export function UserProfile({ userId }: UserProfileProps) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchUser();
  }, [userId]);

  // ... rest of component
}
```

### Backend/API

- Use RESTful conventions
- Validate all inputs with Zod
- Use proper HTTP status codes
- Return consistent error formats
- Add rate limiting for public endpoints
- Use middleware for common concerns (auth, logging)

#### Example:

```typescript
// Good
router.post('/api/users',
  authMiddleware,
  async (req: Request, res: Response) => {
    try {
      const validated = createUserSchema.parse(req.body);
      const user = await createUser(validated);
      res.status(201).json({ success: true, data: user });
    } catch (error) {
      if (error instanceof ZodError) {
        res.status(400).json({
          success: false,
          error: 'Validation failed',
          details: error.errors
        });
      } else {
        res.status(500).json({
          success: false,
          error: 'Internal server error'
        });
      }
    }
  }
);
```

### Database/Prisma

- Use transactions for related updates
- Add proper indexes for queried fields
- Use meaningful model and field names
- Add comments to complex schema relationships

### PowerShell Scripts

- Use approved verbs (Get, Set, Start, Stop, Test)
- Add help comments
- Use proper error handling
- Use `$procId` instead of `$pid` (reserved variable)

## 💬 Commit Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format
=======
npm run lint
npm test
```

### 8. Commit Your Changes

Follow our [commit guidelines](#commit-guidelines):

```bash
git add .
git commit -m "feat: Add user profile page"
```

### 9. Push to Your Fork

```bash
git push origin feature/your-feature-name
```

### 10. Create a Pull Request

Go to GitHub and create a Pull Request from your branch to the main repository.

---

## 🎨 Coding Standards

### General Principles

- **Keep it simple** - Write clear, readable code
- **Follow existing patterns** - Match the style of existing code
- **Comment wisely** - Explain "why", not "what"
- **Test your changes** - Ensure nothing breaks

### TypeScript

```typescript
// ✅ Good - Clear type definitions
interface User {
  id: string;
  email: string;
  roles: string[];
}

function getUserById(id: string): Promise<User | null> {
  // Implementation
}

// ❌ Bad - Using 'any' type
function getUser(id: any): any {
  // Implementation
}
```

### Backend (NestJS/Express)

```typescript
// ✅ Good - Proper error handling
app.post("/api/users", async (req, res) => {
  try {
    const user = await createUser(req.body);
    res.json({ success: true, user });
  } catch (error) {
    console.error("Failed to create user:", error);
    res.status(500).json({ error: "Failed to create user" });
  }
});

// ❌ Bad - No error handling
app.post("/api/users", async (req, res) => {
  const user = await createUser(req.body);
  res.json(user);
});
```

### Frontend (React)

```typescript
// ✅ Good - Functional component with proper hooks
import { useState, useEffect } from "react";

function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState<User | null>(null);
  
  useEffect(() => {
    fetchUser(userId).then(setUser);
  }, [userId]);
  
  if (!user) return <div>Loading...</div>;
  
  return <div>{user.email}</div>;
}

// ❌ Bad - Missing types and dependencies
function UserProfile({ userId }) {
  const [user, setUser] = useState(null);
  
  useEffect(() => {
    fetchUser(userId).then(setUser);
  }, []); // Missing userId dependency
  
  return <div>{user.email}</div>;
}
```

### File Organization

```
src/
├── components/       # Reusable UI components
├── pages/           # Page components
├── lib/             # Utilities and helpers
├── hooks/           # Custom React hooks
├── types/           # TypeScript type definitions
├── api/             # API client functions
└── config/          # Configuration files
```

### Naming Conventions

- **Files**: `kebab-case.tsx` or `PascalCase.tsx` for components
- **Components**: `PascalCase`
- **Functions**: `camelCase`
- **Constants**: `UPPER_SNAKE_CASE`
- **Interfaces/Types**: `PascalCase`

---

## 📝 Commit Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Commit Format
 main
 main

```
<type>(<scope>): <subject>

<body>

<footer>
```

copilot/fix-and-improve-bn88-project
**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(auth): add JWT token refresh endpoint

fix(frontend): resolve proxy configuration for API calls

docs(readme): update installation instructions

chore(deps): upgrade Prisma to v6.19.2
```

### Commit Best Practices

- Keep commits small and focused
- Write clear, descriptive commit messages
- Reference issue numbers when applicable
- Don't commit sensitive data (API keys, passwords, etc.)
- Don't commit `node_modules` or build artifacts

## 🔄 Pull Request Process

1. **Update your branch**
   ```bash
   git fetch origin
   git rebase origin/main
   ```

2. **Run all checks**
   ```bash
   # Backend
   cd bn88-backend-v12
   npm run typecheck
   npm test
   
   # Frontend
   cd ../bn88-frontend-dashboard-v12
   npm run lint
   npm run typecheck
   npm test
   ```

3. **Create Pull Request**
   - Use a descriptive title
   - Reference related issues
   - Describe what changed and why
   - Include screenshots for UI changes
   - Mark as draft if work in progress

4. **PR Template**
   ```markdown
   ## Description
   Brief description of changes
   
   ## Type of Change
   - [ ] Bug fix
   - [ ] New feature
   - [ ] Breaking change
   - [ ] Documentation update
   
   ## Testing
   - [ ] Unit tests pass
   - [ ] Integration tests pass
   - [ ] Manual testing completed
   
   ## Screenshots (if applicable)
   [Add screenshots here]
   
   ## Related Issues
   Closes #123
   ```

5. **Review Process**
   - Address review comments
   - Update code as needed
   - Request re-review when ready

6. **After Merge**
   - Delete your feature branch
   - Pull latest changes from main

## 🔐 Security

- Never commit sensitive data
- Use environment variables for secrets
- Review `.gitignore` before committing
- Report security vulnerabilities privately
- Follow security best practices

## 🐛 Bug Reports

When reporting bugs, include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, Node version, etc.)
- Error messages or logs
- Screenshots if applicable

## 💡 Feature Requests

When requesting features, include:
- Clear description of the feature
- Use case and benefits
- Any relevant examples or mockups
- Potential implementation approach

## 📞 Getting Help

- Check existing documentation
- Search closed issues
- Ask in project discussions
- Contact maintainers

## 🙏 Thank You

Your contributions help make this project better!

---

**Note**: These guidelines may evolve over time. Check back regularly for updates.
=======
### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `perf`: Performance improvements

### Examples

 copilot/fix-bn88-project-issues-again
```powershell
# Feature
git commit -m "feat(auth): add password reset functionality"

# Bug fix
git commit -m "fix(api): correct pagination offset calculation"

# Documentation
git commit -m "docs(readme): update installation instructions"

# Breaking change
git commit -m "feat(api): redesign authentication flow

BREAKING CHANGE: Auth endpoints now require x-tenant header"
```

### Best Practices

- Keep the subject line under 50 characters
- Use imperative mood ("add" not "added")
- Don't end the subject line with a period
- Separate subject from body with a blank line
- Wrap body at 72 characters
- Explain what and why, not how

## 🔍 Pull Request Process

### Before Submitting

- [ ] Code follows the style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] No new warnings
- [ ] Commits follow guidelines

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
How have you tested this?

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-reviewed
- [ ] Commented complex code
- [ ] Updated documentation
- [ ] Added tests
- [ ] Tests pass
- [ ] No new warnings

## Screenshots (if applicable)
Add screenshots for UI changes
```

### Review Process

1. **Automated Checks:** GitHub Actions will run tests
2. **Code Review:** Maintainers will review your code
3. **Feedback:** Address any requested changes
4. **Approval:** Once approved, your PR will be merged

### After Merge

- Delete your feature branch
- Update your fork:
  ```powershell
  git checkout main
  git pull upstream main
  git push origin main
  ```

## ✅ Testing

### Writing Tests

- Write tests for new features
- Update tests for bug fixes
- Aim for good coverage (not 100%, but reasonable)
- Test edge cases and error conditions

### Running Tests

```powershell
# Backend
cd bn88-backend-v12
npm test

# Frontend
cd bn88-frontend-dashboard-v12
npm test

# Smoke tests
.\smoke.ps1
```


```bash
# Feature
git commit -m "feat(auth): Add password reset functionality"

# Bug fix
git commit -m "fix(api): Resolve token expiration issue"

# Documentation
git commit -m "docs(readme): Update installation instructions"

# Refactor
git commit -m "refactor(utils): Simplify date formatting function"

# Multiple lines
git commit -m "feat(dashboard): Add user analytics page

- Add analytics API endpoint
- Create charts component
- Update navigation menu

Closes #123"
```

### Commit Message Best Practices

- **Use imperative mood**: "Add feature" not "Added feature"
- **Be concise**: Keep the subject line under 50 characters
- **Be specific**: Describe what changed and why
- **Reference issues**: Use "Fixes #123" or "Closes #123"

---

## 🔄 Pull Request Process

### Before Creating a PR

- [ ] Your code follows the coding standards
- [ ] You've tested your changes locally
- [ ] All tests pass
- [ ] You've updated documentation if needed
- [ ] Your commits follow the commit guidelines
- [ ] Your branch is up to date with main

### Creating the PR

1. **Title**: Use a clear, descriptive title
   ```
   feat: Add user profile page
   fix: Resolve login token expiration
   docs: Update API documentation
   ```

2. **Description**: Provide context and details
   ```markdown
   ## Description
   Adds a new user profile page with the following features:
   - Display user information
   - Edit profile functionality
   - Avatar upload
   
   ## Changes
   - Added ProfilePage component
   - Created profile API endpoints
   - Updated navigation menu
   
   ## Testing
   - Tested profile editing
   - Verified avatar upload
   - Checked responsive design
   
   ## Screenshots
   [If applicable, add screenshots]
   
   Fixes #123
   ```

3. **Link Issues**: Reference related issues using keywords:
   - `Fixes #123` - Closes the issue when PR is merged
   - `Closes #123` - Same as Fixes
   - `Related to #123` - References without closing

### PR Review Process

1. **Automated Checks**: Wait for CI/CD to pass
2. **Code Review**: Address reviewer comments
3. **Make Changes**: Push additional commits if needed
4. **Approval**: Get approval from maintainers
5. **Merge**: Maintainers will merge your PR

### Responding to Feedback

- **Be respectful**: Accept criticism professionally
- **Ask questions**: If feedback is unclear
- **Make changes**: Update your code based on feedback
- **Explain decisions**: If you disagree, explain why

---

## 🧪 Testing

### Running Tests

```bash
# Backend
cd bn88-backend-v12
npm test                  # Run all tests
npm run typecheck         # Type checking

# Frontend
cd bn88-frontend-dashboard-v12
npm test                  # Run all tests
npm run typecheck         # Type checking
npm run lint              # Linting
```

### Writing Tests

```typescript
// Example test
describe("User Authentication", () => {
  it("should login with valid credentials", async () => {
    const response = await login("user@example.com", "password");
    expect(response.token).toBeDefined();
  });
  
  it("should reject invalid credentials", async () => {
    await expect(
      login("user@example.com", "wrong")
    ).rejects.toThrow();
  });
});
```

### Manual Testing

Before submitting a PR:

1. **Start the dev servers**: `.\start-dev.ps1`
2. **Test your changes**: Verify functionality works
3. **Test edge cases**: Try invalid inputs, errors, etc.
4. **Test on different browsers**: Chrome, Firefox, Safari
5. **Run smoke tests**: `.\smoke.ps1`



 main
## 📚 Documentation

### When to Update Documentation

Update documentation when you:
 copilot/fix-bn88-project-issues-again
- Add a new feature
- Change existing behavior
- Fix a bug that affects usage
- Add new configuration options
- Change API endpoints

### Documentation Files

- `README.md` - Project overview
- `SETUP.md` - Installation guide
- `RUNBOOK.md` - Operations guide
- `CONTRIBUTING.md` - This file
- Code comments - Inline documentation
- API documentation - OpenAPI/Swagger

### Documentation Style

- Use clear, simple language
- Include code examples
- Add screenshots for UI changes
- Keep it up-to-date
- Use proper markdown formatting

## 🎯 Areas Needing Contribution

We especially welcome contributions in:

### High Priority
- Bug fixes
- Performance improvements
- Security enhancements
- Documentation improvements
- Test coverage

### Features
- New bot capabilities
- Enhanced dashboard features
- Better error handling
- Improved logging
- Multi-language support

### Infrastructure
- CI/CD improvements
- Deployment automation
- Monitoring setup
- Docker improvements

- Add new features
- Change existing functionality
- Add new configuration options
- Fix significant bugs
- Add new APIs or endpoints

### Documentation Files

- `README.md` - Main project documentation
- `SETUP.md` - Setup and installation guide
- `CONTRIBUTING.md` - This file
- `RUNBOOK.md` - Operations guide
- Code comments - Inline documentation

### Writing Good Documentation

```markdown
## Good Example

### User Authentication

To authenticate a user, send a POST request to `/api/auth/login`:

\`\`\`http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "password123"
}
\`\`\`

Response:
\`\`\`json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "123",
    "email": "user@example.com"
  }
}
\`\`\`
```

---
 main

## ❓ Questions?

If you have questions:

 copilot/fix-bn88-project-issues-again
1. Check existing documentation
2. Search closed issues
3. Ask in a new issue
4. Tag it with `question`

## 🙏 Thank You

Thank you for contributing to BN88! Every contribution, no matter how small, helps make this project better for everyone.



**Remember:** The goal is to make the project better, not perfect. Don't be afraid to contribute!

1. Check existing [documentation](README.md)
2. Search [issues](https://github.com/josho007237-max/-bn88-new-clean/issues)
3. Ask in the issue you're working on
4. Create a new issue with the `question` label

---

## 🎉 Thank You!

Your contributions help make BN88 better for everyone. We appreciate your time and effort!

---

**Happy Contributing! 🚀**
main
 main
