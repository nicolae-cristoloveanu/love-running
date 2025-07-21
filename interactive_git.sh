#!/bin/bash

# Interactive Git Workflow Script
# Author: Created for streamlined git operations
# Description: Provides interactive prompts for git add, commit, and push operations

set -e  # Exit on any error

# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_question() {
    echo -e "${BLUE}[QUESTION]${NC} $1"
}

# Function to check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository. Please run this script from within a git repository."
        exit 1
    fi
}

# Function to show git status
show_status() {
    print_status "Current git status:"
    echo "─────────────────────────────"
    git status --short
    echo "─────────────────────────────"
}

# Function to handle git add
handle_git_add() {
    echo
    print_status "=== GIT ADD STAGE ==="
    show_status
    
    if [[ -z $(git status --porcelain) ]]; then
        print_warning "No changes detected. Nothing to add."
        return 1
    fi
    
    echo
    print_question "What would you like to add?"
    echo "1) Add all changes (git add .)"
    echo "2) Add specific files"
    echo "3) Add all tracked files only (git add -u)"
    echo "4) Skip adding files"
    echo
    read -p "Enter your choice (1-4): " add_choice
    
    case $add_choice in
        1)
            print_status "Adding all changes..."
            git add .
            print_status "All changes added successfully!"
            ;;
        2)
            echo
            print_status "Available files to add:"
            git status --porcelain | grep -E "^(\?\?|M |A | M)" | cut -c4-
            echo
            read -p "Enter file names (space-separated): " files
            if [[ -n "$files" ]]; then
                git add $files
                print_status "Selected files added successfully!"
            else
                print_warning "No files specified."
                return 1
            fi
            ;;
        3)
            print_status "Adding all tracked files..."
            git add -u
            print_status "All tracked files added successfully!"
            ;;
        4)
            print_warning "Skipping git add stage."
            return 1
            ;;
        *)
            print_error "Invalid choice. Skipping git add stage."
            return 1
            ;;
    esac
    
    echo
    print_status "Files staged for commit:"
    git diff --cached --name-only
    return 0
}

# Function to handle git commit
handle_git_commit() {
    echo
    print_status "=== GIT COMMIT STAGE ==="
    
    # Check if there are staged changes
    if [[ -z $(git diff --cached --name-only) ]]; then
        print_warning "No staged changes to commit."
        return 1
    fi
    
    echo
    print_question "How would you like to create your commit?"
    echo "1) Write commit message now"
    echo "2) Open editor for detailed commit message"
    echo "3) Use conventional commit format"
    echo "4) Skip commit"
    echo
    read -p "Enter your choice (1-4): " commit_choice
    
    case $commit_choice in
        1)
            read -p "Enter commit message: " commit_msg
            if [[ -n "$commit_msg" ]]; then
                git commit -m "$commit_msg"
                print_status "Commit created successfully!"
            else
                print_error "Commit message cannot be empty."
                return 1
            fi
            ;;
        2)
            print_status "Opening editor for commit message..."
            git commit
            print_status "Commit created successfully!"
            ;;
        3)
            echo
            print_status "Conventional commit types:"
            echo "feat: A new feature"
            echo "fix: A bug fix"
            echo "docs: Documentation only changes"
            echo "style: Changes that do not affect the meaning of the code"
            echo "refactor: A code change that neither fixes a bug nor adds a feature"
            echo "test: Adding missing tests or correcting existing tests"
            echo "chore: Changes to the build process or auxiliary tools"
            echo
            read -p "Enter commit type: " commit_type
            read -p "Enter brief description: " commit_desc
            
            if [[ -n "$commit_type" && -n "$commit_desc" ]]; then
                git commit -m "$commit_type: $commit_desc"
                print_status "Conventional commit created successfully!"
            else
                print_error "Both commit type and description are required."
                return 1
            fi
            ;;
        4)
            print_warning "Skipping commit stage."
            return 1
            ;;
        *)
            print_error "Invalid choice. Skipping commit stage."
            return 1
            ;;
    esac
    return 0
}

# Function to handle git push
handle_git_push() {
    echo
    print_status "=== GIT PUSH STAGE ==="
    
    # Check if there are unpushed commits
    current_branch=$(git branch --show-current)
    
    # Check if remote branch exists
    if ! git ls-remote --exit-code --heads origin "$current_branch" > /dev/null 2>&1; then
        print_warning "Remote branch '$current_branch' doesn't exist."
        echo
        print_question "Would you like to push and set upstream? (y/n)"
        read -p "Choice: " setup_upstream
        
        if [[ "$setup_upstream" =~ ^[Yy]$ ]]; then
            print_status "Pushing and setting upstream..."
            git push -u origin "$current_branch"
            print_status "Successfully pushed and set upstream!"
        else
            print_warning "Skipping push stage."
            return 1
        fi
        return 0
    fi
    
    # Check if there are commits to push
    if [[ -z $(git log origin/$current_branch..HEAD) ]]; then
        print_warning "No new commits to push."
        return 1
    fi
    
    echo
    print_status "Commits ready to push:"
    git log --oneline origin/$current_branch..HEAD
    echo
    
    print_question "How would you like to push?"
    echo "1) Push to current branch (git push)"
    echo "2) Force push (git push --force-with-lease)"
    echo "3) Push with tags (git push --tags)"
    echo "4) Skip push"
    echo
    read -p "Enter your choice (1-4): " push_choice
    
    case $push_choice in
        1)
            print_status "Pushing to origin/$current_branch..."
            git push
            print_status "Push completed successfully!"
            ;;
        2)
            print_warning "Force push can overwrite remote changes!"
            read -p "Are you sure? (y/n): " confirm_force
            if [[ "$confirm_force" =~ ^[Yy]$ ]]; then
                git push --force-with-lease
                print_status "Force push completed successfully!"
            else
                print_warning "Force push cancelled."
                return 1
            fi
            ;;
        3)
            print_status "Pushing with tags..."
            git push && git push --tags
            print_status "Push with tags completed successfully!"
            ;;
        4)
            print_warning "Skipping push stage."
            return 1
            ;;
        *)
            print_error "Invalid choice. Skipping push stage."
            return 1
            ;;
    esac
    return 0
}

# Main function
main() {
    echo
    echo "╔══════════════════════════════════════╗"
    echo "║       Interactive Git Workflow       ║"
    echo "╚══════════════════════════════════════╝"
    echo
    
    # Check if we're in a git repository
    check_git_repo
    
    # Show initial status
    show_status
    
    # Process stages
    add_success=false
    commit_success=false
    
    # Git Add Stage
    if handle_git_add; then
        add_success=true
    fi
    
    # Git Commit Stage (only if add was successful)
    if $add_success; then
        if handle_git_commit; then
            commit_success=true
        fi
    fi
    
    # Git Push Stage (only if commit was successful)
    if $commit_success; then
        handle_git_push
    fi
    
    echo
    print_status "=== WORKFLOW COMPLETE ==="
    show_status
    echo
    print_status "Thank you for using Interactive Git Workflow!"
}

# Run main function
main "$@"
