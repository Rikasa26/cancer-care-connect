<?php
require_once __DIR__ . '/includes/auth.php';
if (isLoggedIn()) redirect(homeFor($_SESSION['user_role']));

$errors = [];
$old = $_POST;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    verifyCsrf();
    $role     = $_POST['role'] ?? 'patient';
    $name     = trim($_POST['name'] ?? '');
    $email    = strtolower(trim($_POST['email'] ?? ''));
    $phone    = trim($_POST['phone'] ?? '');
    $district = $_POST['district'] ?? '';
    $password = $_POST['password'] ?? '';

    // 1. Validate main role selection
    if (!in_array($role, ['patient', 'charity', 'verifier'], true)) {
        $errors[] = 'Choose whether you are a patient, charity, or hospital verifier.';
    }
    if ($name === '') $errors[] = 'Name is required.';
    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) $errors[] = 'Enter a valid email address.';
    if (!preg_match('/^\+?[0-9 \-]{9,20}$/', $phone)) $errors[] = 'Enter a valid phone number.';
    if (!in_array($district, SL_DISTRICTS, true)) $errors[] = 'Choose your district.';
    if (strlen($password) < 8 || !preg_match('/[A-Za-z]/', $password) || !preg_match('/\d/', $password)) {
        $errors[] = 'Password must be 8+ characters with letters and numbers.';
    }
    if ($password !== ($_POST['password2'] ?? '')) $errors[] = 'Passwords do not match.';

    $q = $pdo->prepare('SELECT 1 FROM users WHERE email = ?'); 
    $q->execute([$email]);
    if ($q->fetch()) $errors[] = 'This email is already registered.';

    // 2. Validate role-specific fields
    if ($role === 'patient') {
        $nic = strtoupper(trim($_POST['nic'] ?? ''));
        if (!validNic($nic)) $errors[] = 'Enter a valid NIC (9 digits + V, or 12 digits).';
        $q = $pdo->prepare('SELECT 1 FROM patient_profiles WHERE nic_number = ?'); 
        $q->execute([$nic]);
        if ($q->fetch()) $errors[] = 'A patient with this NIC is already registered.';

    } elseif ($role === 'charity') {
        $regNo = trim($_POST['registration_number'] ?? '');
        $year  = (int)($_POST['established_year'] ?? 0);
        $addr  = trim($_POST['address'] ?? '');
        $desc  = trim($_POST['description'] ?? '');
        $cap   = (float)($_POST['capacity'] ?? 0);
        $ops   = array_values(array_intersect($_POST['operating'] ?? [], SL_DISTRICTS));
        
        if ($regNo === '') $errors[] = 'NGO registration number is required.';
        if ($year < 1900 || $year > (int)date('Y')) $errors[] = 'Enter a valid year established.';
        if ($addr === '' || $desc === '') $errors[] = 'Address and description are required.';
        if (!$ops) $errors[] = 'Select at least one operating district.';
        
        $q = $pdo->prepare('SELECT 1 FROM charities WHERE registration_number = ?'); 
        $q->execute([$regNo]);
        if ($q->fetch()) $errors[] = 'This NGO registration number is already registered.';

    } elseif ($role === 'verifier') {
        $hospitalName = trim($_POST['hospital_name'] ?? '');
        $employeeId   = trim($_POST['employee_id'] ?? '');
        $designation  = trim($_POST['designation'] ?? '');

        if ($hospitalName === '') $errors[] = 'Hospital / Institution name is required.';
        if ($employeeId === '')   $errors[] = 'Staff / Registration ID is required.';
        if ($designation === '')  $errors[] = 'Designation / Role is required.';
    }

    // 3. Insert records if no validation errors exist
    if (!$errors) {
        $pdo->beginTransaction();
        try {
            $ins = $pdo->prepare('INSERT INTO users (name, email, password_hash, role, phone, district, status, hospital_name, employee_id, designation) VALUES (?,?,?,?,?,?,?,?,?,?)');
            $ins->execute([
                $name, 
                $email, 
                password_hash($password, PASSWORD_BCRYPT), 
                $role, 
                $phone, 
                $district, 
                'active',
                $role === 'verifier' ? $hospitalName : null,
                $role === 'verifier' ? $employeeId : null,
                $role === 'verifier' ? $designation : null
            ]);
            $uid = (int)$pdo->lastInsertId();

            if ($role === 'patient') {
                $pdo->prepare('INSERT INTO patient_profiles (user_id, patient_name, nic_number, contact_number, district) VALUES (?,?,?,?,?)')
                    ->execute([$uid, $name, $nic, $phone, $district]);

            } elseif ($role === 'charity') {
                $pdo->prepare('INSERT INTO charities (user_id, organization_name, registration_number, established_year, contact_person, official_email, phone, headquarters_address, district, operating_districts_json, description, monthly_aid_capacity_lkr) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)')
                    ->execute([$uid, $name, $regNo, $year, trim($_POST['contact_person'] ?? $name), $email, $phone, $addr, $district, json_encode($ops), $desc, max(0, $cap)]);
            }

            logAudit($pdo, 'AUTH', 'REGISTER', "New {$role} registered: {$email}", 'info', $uid, $role);

            // Send notification to admins if charity or hospital verifier registers
            if ($role === 'charity' || $role === 'verifier') {
                foreach ($pdo->query("SELECT id FROM users WHERE role='admin' AND status='active'")->fetchAll() as $a) {
                    notify($pdo, (int)$a['id'], "New {$role} awaiting verification", "{$name} registered as {$role} and needs review.", 'system');
                }
            }

            $pdo->commit();

            $msg = ($role === 'charity')
                ? 'Registration received. An administrator must approve your organisation before you can receive requests. You can log in now.'
                : (($role === 'verifier')
                    ? 'Hospital staff registration complete. Your profile is ready. You can log in now.'
                    : 'Registration complete. Log in, finish your medical profile and upload your documents for verification.');

            flash('success', $msg);
            redirect('login.php');

        } catch (Throwable $ex) {
            $pdo->rollBack();
            error_log($ex->getMessage());
            $errors[] = 'Registration failed. Please try again.';
        }
    }
}

$pageTitle = 'Register';
require __DIR__ . '/includes/header.php';
$v = fn($k) => e($old[$k] ?? '');
$activeRole = $old['role'] ?? 'patient';
?>

<div class="row justify-content-center">
  <div class="col-lg-8">
    <div class="card shadow-sm">
      <div class="card-header fw-bold">Create an account</div>
      <div class="card-body p-4">

        <?php if ($errors): ?>
          <div class="alert alert-danger">
            <ul class="mb-0">
              <?php foreach ($errors as $m): ?>
                <li><?= e($m) ?></li>
              <?php endforeach; ?>
            </ul>
          </div>
        <?php endif; ?>

        <form method="post">
          <?= csrfField() ?>
          <div class="row g-3">

            <!-- Role Dropdown Menu -->
            <div class="col-md-6">
              <label class="form-label fw-semibold">I am a</label>
              <select name="role" id="roleSelect" class="form-select" onchange="switchRoleFields()">
                <option value="patient" <?= $activeRole === 'patient' ? 'selected' : '' ?>>Patient / family member</option>
                <option value="charity" <?= $activeRole === 'charity' ? 'selected' : '' ?>>Charity / NGO</option>
                <option value="verifier" <?= $activeRole === 'verifier' ? 'selected' : '' ?>>Hospital / Verifier</option>
              </select>
            </div>

            

            <!-- Patient Specific Fields -->
            <div id="patientFields" class="col-12 <?= $activeRole === 'patient' ? '' : 'd-none' ?>">
              <div class="row g-3">
                <div class="col-md-6">
                  <label class="form-label fw-semibold">Patient NIC number</label>
                  <input name="nic" class="form-control" value="<?= $v('nic') ?>" placeholder="199512345678 or 951234567V">
                </div>
              </div>
            </div>

            <div class="col-md-6">
              <label class="form-label fw-semibold">Full name / organisation name</label>
              <input name="name" class="form-control" value="<?= $v('name') ?>" required>
            </div>

            <div class="col-md-6">
              <label class="form-label fw-semibold">Email</label>
              <input type="email" name="email" class="form-control" value="<?= $v('email') ?>" required>
            </div>

            <div class="col-md-6">
              <label class="form-label fw-semibold">Phone</label>
              <input name="phone" class="form-control" value="<?= $v('phone') ?>" placeholder="+94 77 123 4567" required>
            </div>

            <div class="col-md-6">
              <label class="form-label fw-semibold">District</label>
              <select name="district" class="form-select" required>
                <option value="">Choose...</option>
                <?php foreach (SL_DISTRICTS as $d): ?>
                  <option <?= ($old['district'] ?? '') === $d ? 'selected' : '' ?>><?= e($d) ?></option>
                <?php endforeach; ?>
              </select>
            </div>

            <div class="col-md-6">
              <label class="form-label fw-semibold">Password</label>
              <input type="password" name="password" class="form-control" minlength="8" required>
            </div>

            <div class="col-md-6">
              <label class="form-label fw-semibold">Confirm password</label>
              <input type="password" name="password2" class="form-control" minlength="8" required>
            </div>

            <!-- Charity Specific Fields -->
            <div id="charityFields" class="col-12 <?= $activeRole === 'charity' ? '' : 'd-none' ?>">
              <div class="row g-3">
                <div class="col-md-6">
                  <label class="form-label fw-semibold">NGO registration number</label>
                  <input name="registration_number" class="form-control" value="<?= $v('registration_number') ?>">
                </div>
                <div class="col-md-3">
                  <label class="form-label fw-semibold">Year established</label>
                  <input type="number" name="established_year" class="form-control" value="<?= $v('established_year') ?>">
                </div>
                <div class="col-md-3">
                  <label class="form-label fw-semibold">Monthly capacity (LKR)</label>
                  <input type="number" name="capacity" class="form-control" value="<?= $v('capacity') ?>">
                </div>
                <div class="col-md-6">
                  <label class="form-label fw-semibold">Contact person</label>
                  <input name="contact_person" class="form-control" value="<?= $v('contact_person') ?>">
                </div>
                <div class="col-md-6">
                  <label class="form-label fw-semibold">Headquarters address</label>
                  <input name="address" class="form-control" value="<?= $v('address') ?>">
                </div>
                <div class="col-12">
                  <label class="form-label fw-semibold">What does your organisation do?</label>
                  <textarea name="description" class="form-control" rows="3"><?= $v('description') ?></textarea>
                </div>
                <div class="col-12">
                  <label class="form-label fw-semibold">Operating districts</label>
                  <div class="row">
                    <?php foreach (SL_DISTRICTS as $d): ?>
                      <div class="col-6 col-md-3">
                        <div class="form-check">
                          <input class="form-check-input" type="checkbox" name="operating[]" value="<?= e($d) ?>" id="op<?= e($d) ?>" <?= in_array($d, $old['operating'] ?? [], true) ? 'checked' : '' ?>>
                          <label class="form-check-label small" for="op<?= e($d) ?>"><?= e($d) ?></label>
                        </div>
                      </div>
                    <?php endforeach; ?>
                  </div>
                </div>
              </div>
            </div>

            <!-- Hospital / Verifier Specific Fields -->
            <div id="verifierFields" class="col-12 <?= $activeRole === 'verifier' ? '' : 'd-none' ?>">
              
                
                  <div class="col-md-12">
                    <label class="form-label fw-semibold">Hospital / Institution Name</label>
                    <input name="hospital_name" class="form-control" value="<?= $v('hospital_name') ?>" placeholder="e.g. Apeksha Hospital Maharagama">
                  </div>
                  <div class="col-md-6">
                    <label class="form-label fw-semibold">Staff / Medical Registration ID</label>
                    <input name="employee_id" class="form-control" value="<?= $v('employee_id') ?>" placeholder="e.g. HP-9021">
                  </div>
                  <div class="col-md-6">
                    <label class="form-label fw-semibold">Designation / Role</label>
                    <input name="designation" class="form-control" value="<?= $v('designation') ?>" placeholder="e.g. Oncology Social Worker">
                  </div>
                </div>
              </div>
            </div>

          </div>

          <button class="btn btn-primary mt-4 py-2 px-4 fw-semibold">Register Account</button>
          <a href="<?= url('login.php') ?>" class="btn btn-link mt-4 ms-2">Already registered? Log in</a>
        </form>

      </div>
    </div>
  </div>
</div>

<script>
function switchRoleFields() {
  const selectedRole = document.getElementById('roleSelect').value;
  const patient = document.getElementById('patientFields');
  const charity = document.getElementById('charityFields');
  const verifier = document.getElementById('verifierFields');

  // Force all sub-sections to hide first
  if (patient) patient.classList.add('d-none');
  if (charity) charity.classList.add('d-none');
  if (verifier) verifier.classList.add('d-none');

  // Unhide only the section matching the dropdown value
  if (selectedRole === 'patient' && patient) {
    patient.classList.remove('d-none');
  } else if (selectedRole === 'charity' && charity) {
    charity.classList.remove('d-none');
  } else if (selectedRole === 'verifier' && verifier) {
    verifier.classList.remove('d-none');
  }
}

// Run as soon as page loads
document.addEventListener('DOMContentLoaded', switchRoleFields);
</script>

<?php require __DIR__ . '/includes/footer.php'; ?>